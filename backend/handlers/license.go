package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/labstack/echo/v4"
)

// LicenseRequest 客户端发送的激活请求
type LicenseRequest struct {
	LicenseKey   string `json:"license_key"`
	InstanceName string `json:"instance_name"`
}

// LemonSqueezyResponse Lemon Squeezy 激活接口的响应结构
type LemonSqueezyResponse struct {
	Activated bool   `json:"activated"`
	Error     string `json:"error"`
	LicenseKey struct {
		ID             int    `json:"id"`
		Status         string `json:"status"`
		Key            string `json:"key"`
		ActivationLimit int   `json:"activation_limit"`
		ActivationCount int   `json:"activation_count"`
		ExpiresAt      string `json:"expires_at"`
	} `json:"license_key"`
}

// VerifyLicenseHandler 核销激活码的处理器
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

	// 准备发送给 Lemon Squeezy 激活 API 的数据
	apiURL := "https://api.lemonsqueezy.com/v1/licenses/activate"
	form := url.Values{}
	form.Set("license_key", req.LicenseKey)
	instanceName := req.InstanceName
	if instanceName == "" {
		instanceName = "DumpIt User Client"
	}
	form.Set("instance_name", instanceName)

	// 创建 HTTP 请求
	httpReq, err := http.NewRequest("POST", apiURL, strings.NewReader(form.Encode()))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to create license activation request: " + err.Error(),
		})
	}

	// 设置 Headers
	httpReq.Header.Set("Accept", "application/json")
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	// 执行请求
	client := &http.Client{}
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

	// 解析响应
	var lsResp LemonSqueezyResponse
	if err := json.Unmarshal(bodyBytes, &lsResp); err != nil {
		// 如果解析 JSON 失败，可能接口返回了错误信息或者是纯文本
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "failed to verify license: key might be invalid or expired",
			"raw":   string(bodyBytes),
		})
	}

	// 判断是否激活成功
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

	// 激活成功！返回加密激活凭证签名（此处为了纯客户端简单处理，返回核销成功的元数据）
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":          true,
		"status":           lsResp.LicenseKey.Status,
		"expires_at":       lsResp.LicenseKey.ExpiresAt,
		"activation_count": lsResp.LicenseKey.ActivationCount,
		"message":          "license activated successfully",
	})
}
