package handlers

import (
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"

	"dumpit-backend/services"
)

const uidContextKey = "uid"

// RequireAuth 校验 Authorization: Bearer <session_token>，通过后把 uid 存入 echo context
func RequireAuth(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		header := c.Request().Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			return c.JSON(http.StatusUnauthorized, map[string]string{"error": "missing bearer token"})
		}

		token := strings.TrimPrefix(header, "Bearer ")
		uid, err := services.ParseSessionToken(token)
		if err != nil {
			return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid or expired session token"})
		}

		c.Set(uidContextKey, uid)
		return next(c)
	}
}

// UIDFromContext 从 echo context 里取出 RequireAuth 存入的 uid
func UIDFromContext(c echo.Context) string {
	uid, _ := c.Get(uidContextKey).(string)
	return uid
}
