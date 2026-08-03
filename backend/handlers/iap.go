package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/labstack/echo/v4"
)

// IAPVerifyRequest 客户端发送的内购验证请求
type IAPVerifyRequest struct {
	ReceiptData string `json:"receipt_data"`
}

// AppleReceiptResponse 苹果验证收据接口返回的响应结构
type AppleReceiptResponse struct {
	Status  int `json:"status"`
	Receipt struct {
		InApp []struct {
			ProductID             string `json:"product_id"`
			TransactionID         string `json:"transaction_id"`
			OriginalTransactionID string `json:"original_transaction_id"`
			ExpiresDateMs         string `json:"expires_date_ms"` // 如果是订阅项目会有过期时间
		} `json:"in_app"`
	} `json:"receipt"`
}

// VerifyIAPHandler 验证 Apple IAP 购买票据的处理器
func VerifyIAPHandler(c echo.Context) error {
	var req IAPVerifyRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
	}

	if req.ReceiptData == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "receipt_data is required",
		})
	}

	// 依次尝试生产网关和沙盒网关（状态码 21007 表示应改用沙盒收据重新校验）
	var success bool
	var status int
	var err error
	for _, gateway := range []string{
		"https://buy.itunes.apple.com/verifyReceipt",
		"https://sandbox.itunes.apple.com/verifyReceipt",
	} {
		success, status, err = verifyReceiptWithApple(gateway, req.ReceiptData)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "failed to connect to Apple Server: " + err.Error(),
			})
		}
		if status != 21007 {
			break
		}
	}

	if !success {
		return c.JSON(http.StatusPaymentRequired, map[string]interface{}{
			"success": false,
			"status":  status,
			"error":   "invalid Apple receipt",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"status":  status,
		"message": "Apple IAP receipt verified successfully",
	})
}

// 向苹果网关发起请求校验
func verifyReceiptWithApple(url string, receiptData string) (bool, int, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	
	reqBody, err := json.Marshal(map[string]string{
		"receipt-data": receiptData,
	})
	if err != nil {
		return false, -1, err
	}

	resp, err := client.Post(url, "application/json", bytes.NewBuffer(reqBody))
	if err != nil {
		return false, -1, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, -1, err
	}

	var appleResp AppleReceiptResponse
	if err := json.Unmarshal(bodyBytes, &appleResp); err != nil {
		return false, -1, err
	}

	// status == 0 表示校验成功且收据有效
	if appleResp.Status == 0 {
		// 必须精确匹配我们自己的黄金会员产品 ID，防止其他 App/商品的收据被误判为已付费；
		// 订阅类商品还需确认尚未过期（终身买断商品没有 expires_date_ms，视为永久有效）
		hasPremium := false
		for _, item := range appleResp.Receipt.InApp {
			if item.ProductID != "dumpit_premium_monthly_sub" && item.ProductID != "dumpit_premium_lifetime_buy" {
				continue
			}
			if item.ExpiresDateMs != "" {
				expiresMs, err := strconv.ParseInt(item.ExpiresDateMs, 10, 64)
				if err != nil || time.UnixMilli(expiresMs).Before(time.Now()) {
					continue
				}
			}
			hasPremium = true
			break
		}

		return hasPremium, appleResp.Status, nil
	}

	return false, appleResp.Status, nil
}
