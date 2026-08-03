package handlers

import (
	"net/http"
	"os"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
	"dumpit-backend/services"
)

// AuthVerifyRequest 客户端发送的登录请求
type AuthVerifyRequest struct {
	IDToken string `json:"id_token"`
}

// VerifyAuthHandler 校验 Firebase ID Token，首次登录自动建号，返回后端签发的 session token
func VerifyAuthHandler(c echo.Context) error {
	var req AuthVerifyRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if req.IDToken == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "id_token is required"})
	}

	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	if projectID == "" {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "FIREBASE_PROJECT_ID is not configured"})
	}

	uid, phoneNumber, err := services.VerifyFirebaseIDToken(req.IDToken, projectID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid firebase id token: " + err.Error()})
	}

	if err := db.UpsertUser(c.Request().Context(), uid, phoneNumber); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create/update user: " + err.Error()})
	}

	sessionToken, err := services.IssueSessionToken(uid)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to issue session token: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":       true,
		"uid":           uid,
		"session_token": sessionToken,
	})
}
