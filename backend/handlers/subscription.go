package handlers

import (
	"net/http"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
)

// GetSubscriptionHandler 返回当前登录账号的订阅状态；不存在订阅记录时 subscribed 为 false
func GetSubscriptionHandler(c echo.Context) error {
	uid := UIDFromContext(c)

	sub, err := db.GetSubscription(c.Request().Context(), uid)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query subscription: " + err.Error()})
	}
	if sub == nil {
		return c.JSON(http.StatusOK, map[string]interface{}{"subscribed": false})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"subscribed": true,
		"product_id": sub.ProductID,
		"expires_at": sub.ExpiresAt,
		"source":     sub.Source,
	})
}
