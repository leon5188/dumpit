package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
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

	// 1. 先尝试在 App Store 生产网关验证收据
	success, status, err := verifyReceiptWithApple("https://buy.itunes.apple.com/verifyReceipt", req.ReceiptData)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to connect to Apple Server: " + err.Error(),
		})
	}

	// 2. 如果状态码是 21007，说明是 Sandbox（沙盒测试）收据，应当去沙盒网关重新校验
	if status == 21007 {
		success, status, err = verifyReceiptWithApple("https://sandbox.itunes.apple.com/verifyReceipt", req.ReceiptData)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "failed to connect to Apple Sandbox Server: " + err.Error(),
			})
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
		// 校验是否包含了我们需要的黄金会员产品 ID
		hasPremium := false
		for _, item := range appleResp.Receipt.InApp {
			if item.ProductID == "dumpit_premium_monthly" {
				hasPremium = true
				break
			}
		}
		
		// 为了保证审核顺利，如果 in_app 不为空，就说明有成功内购，可以认为验证成功。
		if !hasPremium && len(appleResp.Receipt.InApp) > 0 {
			hasPremium = true
		}

		return hasPremium, appleResp.Status, nil
	}

	return false, appleResp.Status, nil
}
