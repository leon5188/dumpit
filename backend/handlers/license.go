package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
)

// LicenseRequest 客户端发送的激活请求
type LicenseRequest struct {
	LicenseKey   string `json:"license_key"`
	InstanceName string `json:"instance_name"`
}

// LemonSqueezyResponse Lemon Squeezy 激活接口的响应结构
type LemonSqueezyResponse struct {
	Activated  bool   `json:"activated"`
	Error      string `json:"error"`
	LicenseKey struct {
		ID              int    `json:"id"`
		Status          string `json:"status"`
		Key             string `json:"key"`
		ActivationLimit int    `json:"activation_limit"`
		ActivationCount int    `json:"activation_count"`
		ExpiresAt       string `json:"expires_at"`
	} `json:"license_key"`
}

// VerifyLicenseHandler 核销激活码，成功后把订阅状态写入当前登录账号
func VerifyLicenseHandler(c echo.Context) error {
	var req LicenseRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
	}

	if req.LicenseKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "license key is required",
		})
	}

	uid := UIDFromContext(c)

	// 🔑 本地测试万能激活码判定（仅在显式设置 APP_ENV=development 的本地/测试环境生效，
	// 生产环境不设置该变量则测试码自动失效，防止被逆向找到后白嫖激活）
	isTestKey := req.LicenseKey == "BRAINVENT-LOCAL-PRO-2026" || req.LicenseKey == "LOCAL-TEST-KEY"
	if isTestKey && os.Getenv("APP_ENV") == "development" {
		testExpiry := time.Date(2099, 12, 31, 23, 59, 59, 0, time.UTC)
		if err := db.UpsertSubscription(c.Request().Context(), uid, "brainvent_local_test_license", &testExpiry, "license_code"); err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "failed to save subscription: " + err.Error(),
			})
		}
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":          true,
			"status":           "active",
			"expires_at":       "2099-12-31T23:59:59Z",
			"activation_count": 1,
			"message":          "local test license activated successfully",
		})
	}

	// 准备发送给 Lemon Squeezy 激活 API 的数据
	apiURL := "https://api.lemonsqueezy.com/v1/licenses/activate"
	form := url.Values{}
	form.Set("license_key", req.LicenseKey)
	instanceName := req.InstanceName
	if instanceName == "" {
		instanceName = "BrainVent User Client"
	}
	form.Set("instance_name", instanceName)

	httpReq, err := http.NewRequestWithContext(c.Request().Context(), "POST", apiURL, strings.NewReader(form.Encode()))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to create license activation request: " + err.Error(),
		})
	}

	httpReq.Header.Set("Accept", "application/json")
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to contact Lemon Squeezy: " + err.Error(),
		})
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to read Lemon Squeezy response: " + err.Error(),
		})
	}

	var lsResp LemonSqueezyResponse
	if err := json.Unmarshal(bodyBytes, &lsResp); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "failed to verify license: key might be invalid or expired",
			"raw":   string(bodyBytes),
		})
	}

	if lsResp.Error != "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": lsResp.Error,
		})
	}

	if !lsResp.Activated && lsResp.LicenseKey.Status != "active" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "license is inactive or expired. status: " + lsResp.LicenseKey.Status,
		})
	}

	var expiresAt *time.Time
	if lsResp.LicenseKey.ExpiresAt != "" {
		if parsed, err := time.Parse(time.RFC3339, lsResp.LicenseKey.ExpiresAt); err == nil {
			expiresAt = &parsed
		}
	}

	if err := db.UpsertSubscription(c.Request().Context(), uid, "brainvent_premium_license", expiresAt, "license_code"); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to save subscription: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":          true,
		"status":           lsResp.LicenseKey.Status,
		"expires_at":       lsResp.LicenseKey.ExpiresAt,
		"activation_count": lsResp.LicenseKey.ActivationCount,
		"message":          "license activated successfully",
	})
}
