package services

import (
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// SessionClaims 是后端自签发 session token 携带的信息
type SessionClaims struct {
	UID string `json:"uid"`
	jwt.RegisteredClaims
}

// IssueSessionToken 为已登录的 uid 签发一个 7 天有效期的 session token
func IssueSessionToken(uid string) (string, error) {
	secret := os.Getenv("SESSION_JWT_SECRET")
	if secret == "" {
		return "", fmt.Errorf("SESSION_JWT_SECRET is not configured")
	}

	claims := SessionClaims{
		UID: uid,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// ParseSessionToken 校验并解析 session token，返回其中的 uid
func ParseSessionToken(tokenString string) (uid string, err error) {
	secret := os.Getenv("SESSION_JWT_SECRET")
	if secret == "" {
		return "", fmt.Errorf("SESSION_JWT_SECRET is not configured")
	}

	claims := &SessionClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return "", fmt.Errorf("invalid session token: %w", err)
	}
	if !token.Valid || claims.UID == "" {
		return "", fmt.Errorf("session token missing uid")
	}

	return claims.UID, nil
}
