package services

import (
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const googlePublicKeysURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

// FirebaseClaims 是 Firebase 手机号登录 ID Token 里我们关心的字段
type FirebaseClaims struct {
	PhoneNumber string `json:"phone_number"`
	Email       string `json:"email"`
	jwt.RegisteredClaims
}

type firebaseKeyCache struct {
	mu        sync.Mutex
	keys      map[string]*rsa.PublicKey
	fetchedAt time.Time
}

var keyCache = &firebaseKeyCache{}

// ponytail: 简单 TTL 缓存，不解析响应的 Cache-Control 头；如果 Google 轮换密钥比 1 小时更频繁，
// 需要缩短这个值或改成解析 Cache-Control 里的 max-age
const keyCacheTTL = 1 * time.Hour

func (c *firebaseKeyCache) getKeys() (map[string]*rsa.PublicKey, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.keys != nil && time.Since(c.fetchedAt) < keyCacheTTL {
		return c.keys, nil
	}

	resp, err := http.Get(googlePublicKeysURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch google public keys: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read google public keys response: %w", err)
	}

	var certs map[string]string
	if err := json.Unmarshal(body, &certs); err != nil {
		return nil, fmt.Errorf("failed to parse google public keys: %w", err)
	}

	keys := make(map[string]*rsa.PublicKey, len(certs))
	for kid, certPEM := range certs {
		key, err := jwt.ParseRSAPublicKeyFromPEM([]byte(certPEM))
		if err != nil {
			continue // 跳过无法解析的证书，不阻断其余 key 的加载
		}
		keys[kid] = key
	}

	c.keys = keys
	c.fetchedAt = time.Now()
	return keys, nil
}

// VerifyFirebaseIDToken 校验 Firebase 手机号登录签发的 ID Token，返回 uid 和手机号
func VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, email string, err error) {
	claims := &FirebaseClaims{}
	token, err := jwt.ParseWithClaims(idToken, claims, func(t *jwt.Token) (interface{}, error) {
		kid, ok := t.Header["kid"].(string)
		if !ok {
			return nil, errors.New("token missing kid header")
		}
		keys, err := keyCache.getKeys()
		if err != nil {
			return nil, err
		}
		key, ok := keys[kid]
		if !ok {
			return nil, errors.New("no matching public key for kid")
		}
		return key, nil
	},
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithAudience(projectID),
		jwt.WithIssuer("https://securetoken.google.com/"+projectID),
	)
	if err != nil {
		return "", "", "", fmt.Errorf("invalid firebase id token: %w", err)
	}
	if !token.Valid || claims.Subject == "" {
		return "", "", "", errors.New("firebase id token missing subject (uid)")
	}

	return claims.Subject, claims.PhoneNumber, claims.Email, nil
}
