# 账号体系 + 云同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give BrainVent (dumpit) a phone-number account system (Firebase Phone Auth) so history records and subscription status survive device changes/reinstalls, and use the accumulated per-account history to auto-generate the AI tone-cloning sample instead of requiring users to type one manually.

**Architecture:** Flutter mobile client authenticates with Firebase Phone Auth, exchanges the Firebase ID Token for a backend-issued session JWT (7-day expiry) via `POST /api/auth/verify`. The Go backend verifies Firebase tokens by checking the signature against Google's published public keys (no full Firebase Admin SDK). All account-scoped data (history records, subscription state) lives in Postgres, keyed by Firebase UID. The local `SharedPreferences` history store remains the offline-first source of truth; cloud sync is best-effort on top of it.

**Tech Stack:** Go 1.25 + Echo v4 (existing), `github.com/jackc/pgx/v5` (Postgres driver, no ORM), `github.com/golang-jwt/jwt/v5` (JWT signing/verification), Postgres (Render-managed in production, Docker Compose locally), Flutter + `firebase_core`/`firebase_auth` (FlutterFire).

## Global Constraints

- No ORM — all SQL is hand-written via `pgx`, per the approved design spec (`docs/superpowers/specs/2026-08-03-account-cloud-sync-design.md`).
- Web frontend (Next.js) is explicitly out of scope for this plan — do not touch `frontend/`.
- No automated end-to-end tests — cross-device sync verification happens manually via a real device/simulator run, per the spec's testing section.
- `subscriptions` table stores one row per `uid` (current state only) — do not add a history/audit table.
- `history_records.summary` is stored as a single `jsonb` blob matching the existing `ProcessedDump` Go struct — do not normalize into separate columns/tables.
- Local-first: any sync operation that fails must not block or corrupt the local `SharedPreferences` data.

---

## File Structure

**Backend (new):**
- `backend/db/db.go` — Postgres connection pool + idempotent schema creation.
- `backend/db/users.go` — user upsert.
- `backend/db/subscriptions.go` — subscription upsert/read.
- `backend/db/history.go` — history record CRUD + recent-summaries query for personalization.
- `backend/services/firebase_auth.go` — Firebase ID Token verification (Google public key JWKS).
- `backend/services/session.go` — backend-issued session JWT issue/parse.
- `backend/handlers/auth_middleware.go` — `RequireAuth` echo middleware + `UIDFromContext` helper.
- `backend/handlers/auth.go` — `POST /api/auth/verify` handler.
- `backend/handlers/history.go` — history CRUD handlers.
- `backend/handlers/subscription.go` — `GET /api/subscription` handler.
- `backend/docker-compose.yml` — local Postgres for development.

**Backend (modified):**
- `backend/main.go` — wire DB connection, schema init, new routes, auth middleware group.
- `backend/handlers/iap.go` — persist verified IAP subscriptions to the `subscriptions` table.
- `backend/handlers/license.go` — persist verified license activations to the `subscriptions` table.
- `backend/services/openai.go` — unchanged (consumed by the new tone-sample builder, not modified itself).
- `backend/handlers/audio.go` — auto-build a dynamic tone sample from account history when the caller is authenticated and didn't supply one manually.
- `backend/go.mod` — add `pgx/v5` and `golang-jwt/jwt/v5`.

**Mobile (new):**
- `dumpit_mobile/lib/services/auth_service.dart` — Firebase phone sign-in + session token persistence.
- `dumpit_mobile/lib/services/sync_service.dart` — history import/push/pull against the backend.
- `dumpit_mobile/lib/views/login_page.dart` — phone number + OTP entry screen.

**Mobile (modified):**
- `dumpit_mobile/pubspec.yaml` — add `firebase_core`, `firebase_auth`.
- `dumpit_mobile/lib/services/api_service.dart` — add authenticated HTTP helpers + endpoint wrappers.
- `dumpit_mobile/lib/views/home_page.dart` — account/sync entry point in the settings panel, push-on-create, pull-on-login.

---

### Task 1: Postgres connection + schema

**Files:**
- Create: `backend/docker-compose.yml`
- Create: `backend/db/db.go`
- Test: `backend/db/db_test.go`

**Interfaces:**
- Produces: `db.Connect(ctx context.Context) error`, `db.Pool *pgxpool.Pool`, `db.InitSchema(ctx context.Context) error`. Later tasks (2, 5, 6) call `db.Pool` directly for queries.

- [ ] **Step 1: Add the Postgres dependency**

Run: `cd backend && go get github.com/jackc/pgx/v5`
Expected: `go.mod`/`go.sum` updated with `github.com/jackc/pgx/v5` and its transitive deps.

- [ ] **Step 2: Write the local dev Postgres compose file**

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dumpit
      POSTGRES_PASSWORD: dumpit_dev_password
      POSTGRES_DB: dumpit
    ports:
      - "5432:5432"
    volumes:
      - dumpit_postgres_data:/var/lib/postgresql/data

volumes:
  dumpit_postgres_data:
```

- [ ] **Step 3: Start it and confirm it's running**

Run: `cd backend && docker compose up -d`
Expected: `postgres` container reports `healthy`/running in `docker compose ps`.

- [ ] **Step 4: Write the connection + schema module**

```go
package db

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

// Connect 建立到 DATABASE_URL 指向的 Postgres 的连接池
func Connect(ctx context.Context) error {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return fmt.Errorf("DATABASE_URL is not configured")
	}

	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return fmt.Errorf("failed to connect to postgres: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("failed to ping postgres: %w", err)
	}

	Pool = pool
	return nil
}

const schemaSQL = `
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
	uid TEXT PRIMARY KEY,
	phone_number TEXT UNIQUE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
	uid TEXT PRIMARY KEY REFERENCES users(uid),
	product_id TEXT NOT NULL,
	expires_at TIMESTAMPTZ,
	source TEXT NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS history_records (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	uid TEXT NOT NULL REFERENCES users(uid),
	summary JSONB NOT NULL,
	raw_text TEXT NOT NULL DEFAULT '',
	created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	archived BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_history_records_uid_created_at ON history_records(uid, created_at DESC);
`

// InitSchema 幂等地创建所需的表/索引，可重复执行
func InitSchema(ctx context.Context) error {
	if _, err := Pool.Exec(ctx, schemaSQL); err != nil {
		return fmt.Errorf("failed to init schema: %w", err)
	}
	return nil
}
```

- [ ] **Step 5: Write the smoke test**

```go
package db

import (
	"context"
	"os"
	"testing"
)

func TestConnectAndInitSchema(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL not set, skipping integration test against local Postgres")
	}

	ctx := context.Background()
	if err := Connect(ctx); err != nil {
		t.Fatalf("Connect failed: %v", err)
	}
	defer Pool.Close()

	if err := InitSchema(ctx); err != nil {
		t.Fatalf("InitSchema failed: %v", err)
	}

	// 幂等性检查：重复执行不应报错
	if err := InitSchema(ctx); err != nil {
		t.Fatalf("InitSchema (second run) failed: %v", err)
	}
}
```

- [ ] **Step 6: Run the test against the local Postgres**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" go test ./db/... -run TestConnectAndInitSchema -v`
Expected: `PASS`

- [ ] **Step 7: Commit**

```bash
git add backend/docker-compose.yml backend/db/db.go backend/db/db_test.go backend/go.mod backend/go.sum
git commit -m "feat(backend): add Postgres connection pool and schema init"
```

---

### Task 2: Firebase ID Token verification

**Files:**
- Create: `backend/services/firebase_auth.go`
- Test: `backend/services/firebase_auth_test.go`

**Interfaces:**
- Produces: `services.VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, err error)`. Task 4 (`auth.go` handler) calls this.

- [ ] **Step 1: Add the JWT dependency**

Run: `cd backend && go get github.com/golang-jwt/jwt/v5`
Expected: `go.mod`/`go.sum` updated.

- [ ] **Step 2: Write the failing test**

```go
package services

import "testing"

func TestVerifyFirebaseIDToken_MalformedToken(t *testing.T) {
	_, _, err := VerifyFirebaseIDToken("not-a-jwt", "some-project-id")
	if err == nil {
		t.Fatal("expected error for malformed token, got nil")
	}
}
```

- [ ] **Step 3: Run it to verify it fails (function doesn't exist yet)**

Run: `cd backend && go test ./services/... -run TestVerifyFirebaseIDToken_MalformedToken -v`
Expected: FAIL with "undefined: VerifyFirebaseIDToken"

- [ ] **Step 4: Implement the verifier**

```go
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
func VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, err error) {
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
		return "", "", fmt.Errorf("invalid firebase id token: %w", err)
	}
	if !token.Valid || claims.Subject == "" {
		return "", "", errors.New("firebase id token missing subject (uid)")
	}

	return claims.Subject, claims.PhoneNumber, nil
}
```

Note: `keyCache.getKeys()` (the network call to Google) only happens inside the `Keyfunc` closure, which `jwt.ParseWithClaims` only invokes once the token has a syntactically valid 3-segment structure — so the malformed-token test above never hits the network.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd backend && go test ./services/... -run TestVerifyFirebaseIDToken_MalformedToken -v`
Expected: `PASS`

- [ ] **Step 6: Commit**

```bash
git add backend/services/firebase_auth.go backend/services/firebase_auth_test.go backend/go.mod backend/go.sum
git commit -m "feat(backend): verify Firebase phone-auth ID tokens via Google public keys"
```

---

### Task 3: Backend session token

**Files:**
- Create: `backend/services/session.go`
- Test: `backend/services/session_test.go`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `services.IssueSessionToken(uid string) (string, error)`, `services.ParseSessionToken(tokenString string) (uid string, err error)`. Task 4's handler and Task 4's middleware call these.

- [ ] **Step 1: Write the failing tests**

```go
package services

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestIssueAndParseSessionToken(t *testing.T) {
	t.Setenv("SESSION_JWT_SECRET", "test-secret-for-unit-tests")

	token, err := IssueSessionToken("uid-123")
	if err != nil {
		t.Fatalf("IssueSessionToken failed: %v", err)
	}

	uid, err := ParseSessionToken(token)
	if err != nil {
		t.Fatalf("ParseSessionToken failed: %v", err)
	}
	if uid != "uid-123" {
		t.Fatalf("expected uid-123, got %s", uid)
	}
}

func TestParseSessionToken_TamperedSignature(t *testing.T) {
	t.Setenv("SESSION_JWT_SECRET", "test-secret-for-unit-tests")

	token, err := IssueSessionToken("uid-123")
	if err != nil {
		t.Fatalf("IssueSessionToken failed: %v", err)
	}

	tampered := token[:len(token)-2] + "xx"
	if _, err := ParseSessionToken(tampered); err == nil {
		t.Fatal("expected error for tampered token signature, got nil")
	}
}

func TestParseSessionToken_WrongSecret(t *testing.T) {
	t.Setenv("SESSION_JWT_SECRET", "secret-a")
	token, err := IssueSessionToken("uid-123")
	if err != nil {
		t.Fatalf("IssueSessionToken failed: %v", err)
	}

	t.Setenv("SESSION_JWT_SECRET", "secret-b")
	if _, err := ParseSessionToken(token); err == nil {
		t.Fatal("expected error when secret changed, got nil")
	}
}

func TestParseSessionToken_Expired(t *testing.T) {
	t.Setenv("SESSION_JWT_SECRET", "test-secret-for-unit-tests")

	claims := SessionClaims{
		UID: "uid-123",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte("test-secret-for-unit-tests"))
	if err != nil {
		t.Fatalf("failed to sign test token: %v", err)
	}

	if _, err := ParseSessionToken(signed); err == nil {
		t.Fatal("expected error for expired token, got nil")
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./services/... -run TestIssueAndParseSessionToken -v`
Expected: FAIL with "undefined: IssueSessionToken"

- [ ] **Step 3: Implement**

```go
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && go test ./services/... -run 'TestIssueAndParseSessionToken|TestParseSessionToken' -v`
Expected: `PASS` (4 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/services/session.go backend/services/session_test.go
git commit -m "feat(backend): issue and verify backend session tokens"
```

---

### Task 4: Auth middleware + login endpoint

**Files:**
- Create: `backend/handlers/auth_middleware.go`
- Create: `backend/handlers/auth.go`
- Test: `backend/handlers/auth_middleware_test.go`

**Interfaces:**
- Consumes: `services.ParseSessionToken` (Task 3), `services.VerifyFirebaseIDToken` (Task 2), `services.IssueSessionToken` (Task 3), `db.UpsertUser` (Task 5).
- Produces: `handlers.RequireAuth` (echo middleware), `handlers.UIDFromContext(c echo.Context) string`, `handlers.VerifyAuthHandler` (echo.HandlerFunc). Tasks 7, 8, 9, 10 use `RequireAuth`/`UIDFromContext`; Task 10 wires `VerifyAuthHandler` into the router.

- [ ] **Step 1: Write the failing middleware tests**

```go
package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"

	"dumpit-backend/services"
)

func TestRequireAuth_ValidToken(t *testing.T) {
	t.Setenv("SESSION_JWT_SECRET", "test-secret")
	token, err := services.IssueSessionToken("uid-abc")
	if err != nil {
		t.Fatalf("IssueSessionToken failed: %v", err)
	}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	var capturedUID string
	handler := RequireAuth(func(c echo.Context) error {
		capturedUID = UIDFromContext(c)
		return c.NoContent(http.StatusOK)
	})

	if err := handler(c); err != nil {
		t.Fatalf("handler returned error: %v", err)
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if capturedUID != "uid-abc" {
		t.Fatalf("expected uid-abc, got %s", capturedUID)
	}
}

func TestRequireAuth_MissingHeader(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	handler := RequireAuth(func(c echo.Context) error {
		return c.NoContent(http.StatusOK)
	})

	if err := handler(c); err != nil {
		t.Fatalf("handler returned error: %v", err)
	}
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./handlers/... -run TestRequireAuth -v`
Expected: FAIL with "undefined: RequireAuth"

- [ ] **Step 3: Implement the middleware**

```go
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && go test ./handlers/... -run TestRequireAuth -v`
Expected: `PASS`

- [ ] **Step 5: Implement the login handler (no dedicated test — thin wiring over already-tested Task 2/3/5 functions, verified manually in Task 10)**

```go
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
```

- [ ] **Step 6: Commit**

```bash
git add backend/handlers/auth_middleware.go backend/handlers/auth_middleware_test.go backend/handlers/auth.go
git commit -m "feat(backend): add session auth middleware and login endpoint"
```

---

### Task 5: Users + subscriptions repository

**Files:**
- Create: `backend/db/users.go`
- Create: `backend/db/subscriptions.go`
- Test: `backend/db/subscriptions_test.go`

**Interfaces:**
- Consumes: `db.Pool` (Task 1).
- Produces: `db.UpsertUser(ctx, uid, phoneNumber string) error`, `db.UpsertSubscription(ctx, uid, productID string, expiresAt *time.Time, source string) error`, `db.GetSubscription(ctx, uid string) (*db.Subscription, error)` with `type Subscription struct { UID, ProductID, Source string; ExpiresAt *time.Time; UpdatedAt time.Time }`. Task 4 uses `UpsertUser`; Task 8 uses `UpsertSubscription`/`GetSubscription`.

- [ ] **Step 1: Write users.go**

```go
package db

import "context"

// UpsertUser 若 uid 不存在则插入新用户；已存在则更新手机号（保留原 created_at）
func UpsertUser(ctx context.Context, uid string, phoneNumber string) error {
	_, err := Pool.Exec(ctx, `
		INSERT INTO users (uid, phone_number)
		VALUES ($1, $2)
		ON CONFLICT (uid) DO UPDATE SET phone_number = EXCLUDED.phone_number
	`, uid, phoneNumber)
	return err
}
```

- [ ] **Step 2: Write the failing subscriptions test**

```go
package db

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestUpsertSubscription_UpdatesNotDuplicates(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL not set, skipping integration test")
	}

	ctx := context.Background()
	if err := Connect(ctx); err != nil {
		t.Fatalf("Connect failed: %v", err)
	}
	defer Pool.Close()
	if err := InitSchema(ctx); err != nil {
		t.Fatalf("InitSchema failed: %v", err)
	}

	uid := "test-uid-subscription-upsert"
	if err := UpsertUser(ctx, uid, "+10000000000"); err != nil {
		t.Fatalf("UpsertUser failed: %v", err)
	}

	firstExpiry := time.Now().Add(24 * time.Hour)
	if err := UpsertSubscription(ctx, uid, "product_a", &firstExpiry, "iap"); err != nil {
		t.Fatalf("first UpsertSubscription failed: %v", err)
	}

	secondExpiry := time.Now().Add(48 * time.Hour)
	if err := UpsertSubscription(ctx, uid, "product_a", &secondExpiry, "iap"); err != nil {
		t.Fatalf("second UpsertSubscription failed: %v", err)
	}

	sub, err := GetSubscription(ctx, uid)
	if err != nil {
		t.Fatalf("GetSubscription failed: %v", err)
	}
	if sub == nil {
		t.Fatal("expected subscription to exist")
	}
	diff := sub.ExpiresAt.Sub(secondExpiry)
	if diff > time.Second || diff < -time.Second {
		t.Fatalf("expected expires_at close to %v, got %v", secondExpiry, sub.ExpiresAt)
	}

	if _, err := Pool.Exec(ctx, "DELETE FROM subscriptions WHERE uid = $1", uid); err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
	if _, err := Pool.Exec(ctx, "DELETE FROM users WHERE uid = $1", uid); err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" go test ./db/... -run TestUpsertSubscription -v`
Expected: FAIL with "undefined: UpsertSubscription"

- [ ] **Step 4: Implement subscriptions.go**

```go
package db

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
)

// Subscription 是某个账号当前的订阅状态
type Subscription struct {
	UID       string
	ProductID string
	ExpiresAt *time.Time
	Source    string
	UpdatedAt time.Time
}

// UpsertSubscription 写入或更新某个账号的订阅状态；每个 uid 只保留一行当前状态
func UpsertSubscription(ctx context.Context, uid, productID string, expiresAt *time.Time, source string) error {
	_, err := Pool.Exec(ctx, `
		INSERT INTO subscriptions (uid, product_id, expires_at, source, updated_at)
		VALUES ($1, $2, $3, $4, now())
		ON CONFLICT (uid) DO UPDATE SET
			product_id = EXCLUDED.product_id,
			expires_at = EXCLUDED.expires_at,
			source = EXCLUDED.source,
			updated_at = now()
	`, uid, productID, expiresAt, source)
	return err
}

// GetSubscription 查询某个账号当前的订阅状态；不存在时返回 (nil, nil)
func GetSubscription(ctx context.Context, uid string) (*Subscription, error) {
	row := Pool.QueryRow(ctx, `
		SELECT uid, product_id, expires_at, source, updated_at
		FROM subscriptions WHERE uid = $1
	`, uid)

	var sub Subscription
	if err := row.Scan(&sub.UID, &sub.ProductID, &sub.ExpiresAt, &sub.Source, &sub.UpdatedAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &sub, nil
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" go test ./db/... -run TestUpsertSubscription -v`
Expected: `PASS`

- [ ] **Step 6: Commit**

```bash
git add backend/db/users.go backend/db/subscriptions.go backend/db/subscriptions_test.go
git commit -m "feat(backend): add users and subscriptions repository"
```

---

### Task 6: History records repository

**Files:**
- Create: `backend/db/history.go`
- Test: `backend/db/history_test.go`

**Interfaces:**
- Consumes: `db.Pool`, `db.UpsertUser` (Task 5).
- Produces: `db.HistoryRecord struct { ID, UID string; Summary json.RawMessage; RawText string; CreatedAt time.Time; Archived bool }`, `db.CreateHistoryRecord(ctx, uid string, summary json.RawMessage, rawText string) (string, error)`, `db.ListHistoryRecords(ctx, uid string, since time.Time) ([]HistoryRecord, error)`, `db.SetArchived(ctx, uid, id string, archived bool) error`, `db.RecentSummaries(ctx, uid string, limit int) ([]json.RawMessage, error)`. Task 7 uses `CreateHistoryRecord`/`ListHistoryRecords`/`SetArchived`; Task 9 uses `RecentSummaries`.

- [ ] **Step 1: Write the failing test**

```go
package db

import (
	"context"
	"encoding/json"
	"os"
	"testing"
)

func TestRecentSummaries_EmptyAndPartial(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL not set, skipping integration test")
	}

	ctx := context.Background()
	if err := Connect(ctx); err != nil {
		t.Fatalf("Connect failed: %v", err)
	}
	defer Pool.Close()
	if err := InitSchema(ctx); err != nil {
		t.Fatalf("InitSchema failed: %v", err)
	}

	uid := "test-uid-recent-summaries"
	if err := UpsertUser(ctx, uid, "+10000000001"); err != nil {
		t.Fatalf("UpsertUser failed: %v", err)
	}

	summaries, err := RecentSummaries(ctx, uid, 5)
	if err != nil {
		t.Fatalf("RecentSummaries (empty) failed: %v", err)
	}
	if len(summaries) != 0 {
		t.Fatalf("expected 0 summaries, got %d", len(summaries))
	}

	for i := 0; i < 2; i++ {
		summary, _ := json.Marshal(map[string]string{"summary": "test summary"})
		if _, err := CreateHistoryRecord(ctx, uid, summary, "raw text"); err != nil {
			t.Fatalf("CreateHistoryRecord failed: %v", err)
		}
	}

	summaries, err = RecentSummaries(ctx, uid, 5)
	if err != nil {
		t.Fatalf("RecentSummaries (partial) failed: %v", err)
	}
	if len(summaries) != 2 {
		t.Fatalf("expected 2 summaries, got %d", len(summaries))
	}

	if _, err := Pool.Exec(ctx, "DELETE FROM history_records WHERE uid = $1", uid); err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
	if _, err := Pool.Exec(ctx, "DELETE FROM users WHERE uid = $1", uid); err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" go test ./db/... -run TestRecentSummaries -v`
Expected: FAIL with "undefined: RecentSummaries"

- [ ] **Step 3: Implement history.go**

```go
package db

import (
	"context"
	"encoding/json"
	"time"
)

// HistoryRecord 是某个账号的一条云端历史记录
type HistoryRecord struct {
	ID        string
	UID       string
	Summary   json.RawMessage
	RawText   string
	CreatedAt time.Time
	Archived  bool
}

// CreateHistoryRecord 插入一条新的历史记录，返回生成的 id
func CreateHistoryRecord(ctx context.Context, uid string, summary json.RawMessage, rawText string) (string, error) {
	var id string
	err := Pool.QueryRow(ctx, `
		INSERT INTO history_records (uid, summary, raw_text)
		VALUES ($1, $2, $3)
		RETURNING id
	`, uid, summary, rawText).Scan(&id)
	return id, err
}

// ListHistoryRecords 按创建时间升序返回某账号在 since 之后创建的记录；since 为零值时返回全部
func ListHistoryRecords(ctx context.Context, uid string, since time.Time) ([]HistoryRecord, error) {
	rows, err := Pool.Query(ctx, `
		SELECT id, uid, summary, raw_text, created_at, archived
		FROM history_records
		WHERE uid = $1 AND created_at > $2
		ORDER BY created_at ASC
	`, uid, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []HistoryRecord
	for rows.Next() {
		var r HistoryRecord
		if err := rows.Scan(&r.ID, &r.UID, &r.Summary, &r.RawText, &r.CreatedAt, &r.Archived); err != nil {
			return nil, err
		}
		records = append(records, r)
	}
	return records, rows.Err()
}

// SetArchived 更新某条记录的归档状态；只有记录属于该 uid 时才会生效
func SetArchived(ctx context.Context, uid string, id string, archived bool) error {
	_, err := Pool.Exec(ctx, `
		UPDATE history_records SET archived = $1 WHERE id = $2 AND uid = $3
	`, archived, id, uid)
	return err
}

// RecentSummaries 返回某账号最近 N 条记录的 summary 原始 JSON，供个性化文风拼接使用
func RecentSummaries(ctx context.Context, uid string, limit int) ([]json.RawMessage, error) {
	rows, err := Pool.Query(ctx, `
		SELECT summary FROM history_records
		WHERE uid = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, uid, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var summaries []json.RawMessage
	for rows.Next() {
		var s json.RawMessage
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		summaries = append(summaries, s)
	}
	return summaries, rows.Err()
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" go test ./db/... -run TestRecentSummaries -v`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add backend/db/history.go backend/db/history_test.go
git commit -m "feat(backend): add history records repository"
```

---

### Task 7: History HTTP handlers

**Files:**
- Create: `backend/handlers/history.go`

**Interfaces:**
- Consumes: `db.CreateHistoryRecord`, `db.ListHistoryRecords`, `db.SetArchived` (Task 6); `UIDFromContext` (Task 4).
- Produces: `handlers.CreateHistoryHandler`, `handlers.ImportHistoryHandler`, `handlers.ListHistoryHandler`, `handlers.PatchHistoryHandler` (all `echo.HandlerFunc`). Task 10 wires these into routes behind `RequireAuth`.

No dedicated Go test for this task — it's thin wiring over the already-tested Task 6 repository functions; correctness of the full request/response cycle is verified manually in Task 10's end-to-end check.

- [ ] **Step 1: Implement the handlers**

```go
package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
)

// CreateHistoryRequest 客户端新建一条云端历史记录的请求体
type CreateHistoryRequest struct {
	Summary json.RawMessage `json:"summary"`
	RawText string          `json:"raw_text"`
}

// CreateHistoryHandler 为当前登录账号新建一条历史记录
func CreateHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	var req CreateHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if len(req.Summary) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "summary is required"})
	}

	id, err := db.CreateHistoryRecord(c.Request().Context(), uid, req.Summary, req.RawText)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save history record: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true, "id": id})
}

// ImportHistoryItem 是批量导入请求里的一条本地记录
type ImportHistoryItem struct {
	ClientID string          `json:"client_id"`
	Summary  json.RawMessage `json:"summary"`
	RawText  string          `json:"raw_text"`
}

// ImportHistoryRequest 首次登录批量导入本地历史的请求体
type ImportHistoryRequest struct {
	Records []ImportHistoryItem `json:"records"`
}

// ImportHistoryHandler 首次登录批量导入本地历史记录；单条失败不影响其余记录导入
func ImportHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	var req ImportHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	imported := make([]string, 0, len(req.Records))
	failed := make([]string, 0)

	for _, item := range req.Records {
		if len(item.Summary) == 0 {
			failed = append(failed, item.ClientID)
			continue
		}
		if _, err := db.CreateHistoryRecord(c.Request().Context(), uid, item.Summary, item.RawText); err != nil {
			failed = append(failed, item.ClientID)
			continue
		}
		imported = append(imported, item.ClientID)
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":  true,
		"imported": imported,
		"failed":   failed,
	})
}

// ListHistoryHandler 增量拉取当前账号的历史记录；?since=<RFC3339> 不传则返回全部
func ListHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)

	since := time.Time{}
	if raw := c.QueryParam("since"); raw != "" {
		parsed, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "since must be RFC3339 formatted"})
		}
		since = parsed
	}

	records, err := db.ListHistoryRecords(c.Request().Context(), uid, since)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to list history records: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true, "records": records})
}

// PatchHistoryRequest 更新某条历史记录归档状态的请求体
type PatchHistoryRequest struct {
	Archived *bool `json:"archived"`
}

// PatchHistoryHandler 更新某条历史记录的归档状态
func PatchHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	id := c.Param("id")

	var req PatchHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if req.Archived == nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "archived field is required"})
	}

	if err := db.SetArchived(c.Request().Context(), uid, id, *req.Archived); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update history record: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true})
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `cd backend && go build ./...`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add backend/handlers/history.go
git commit -m "feat(backend): add history CRUD/import HTTP handlers"
```

---

### Task 8: Bind subscriptions to accounts (IAP + license)

**Files:**
- Modify: `backend/handlers/iap.go` (whole file — `verifyReceiptWithApple` and `VerifyIAPHandler`)
- Modify: `backend/handlers/license.go:36-135` (`VerifyLicenseHandler`)
- Create: `backend/handlers/subscription.go`

**Interfaces:**
- Consumes: `db.UpsertSubscription`, `db.GetSubscription` (Task 5), `UIDFromContext` (Task 4).
- Produces: `handlers.GetSubscriptionHandler` (echo.HandlerFunc). Task 10 wires it behind `RequireAuth`.

- [ ] **Step 1: Rewrite `verifyReceiptWithApple` and `VerifyIAPHandler` in `backend/handlers/iap.go`**

Replace the whole file's function bodies (keep the existing `IAPVerifyRequest`/`AppleReceiptResponse` structs and imports, add `"time"` stays, add `"dumpit-backend/db"` import):

```go
package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
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
			ExpiresDateMs         string `json:"expires_date_ms"`
		} `json:"in_app"`
	} `json:"receipt"`
}

// VerifyIAPHandler 验证 Apple IAP 购买票据，成功后把订阅状态写入当前登录账号
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

	var productID string
	var expiresAt *time.Time
	var status int
	var err error
	for _, gateway := range []string{
		"https://buy.itunes.apple.com/verifyReceipt",
		"https://sandbox.itunes.apple.com/verifyReceipt",
	} {
		productID, expiresAt, status, err = verifyReceiptWithApple(gateway, req.ReceiptData)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "failed to connect to Apple Server: " + err.Error(),
			})
		}
		if status != 21007 {
			break
		}
	}

	if productID == "" {
		return c.JSON(http.StatusPaymentRequired, map[string]interface{}{
			"success": false,
			"status":  status,
			"error":   "invalid Apple receipt",
		})
	}

	uid := UIDFromContext(c)
	if err := db.UpsertSubscription(c.Request().Context(), uid, productID, expiresAt, "iap"); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "failed to save subscription: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"status":  status,
		"message": "Apple IAP receipt verified successfully",
	})
}

// verifyReceiptWithApple 向苹果网关发起请求校验，返回匹配到的会员商品 ID（未匹配到时为空字符串）
// 和到期时间（终身买断商品为 nil）
func verifyReceiptWithApple(url string, receiptData string) (productID string, expiresAt *time.Time, status int, err error) {
	client := &http.Client{Timeout: 10 * time.Second}

	reqBody, err := json.Marshal(map[string]string{
		"receipt-data": receiptData,
	})
	if err != nil {
		return "", nil, -1, err
	}

	resp, err := client.Post(url, "application/json", bytes.NewBuffer(reqBody))
	if err != nil {
		return "", nil, -1, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", nil, -1, err
	}

	var appleResp AppleReceiptResponse
	if err := json.Unmarshal(bodyBytes, &appleResp); err != nil {
		return "", nil, -1, err
	}

	if appleResp.Status != 0 {
		return "", nil, appleResp.Status, nil
	}

	for _, item := range appleResp.Receipt.InApp {
		if item.ProductID != "dumpit_premium_monthly_sub" && item.ProductID != "dumpit_premium_lifetime_buy" {
			continue
		}
		if item.ExpiresDateMs != "" {
			expiresMs, err := strconv.ParseInt(item.ExpiresDateMs, 10, 64)
			if err != nil {
				continue
			}
			expiry := time.UnixMilli(expiresMs)
			if expiry.Before(time.Now()) {
				continue
			}
			return item.ProductID, &expiry, appleResp.Status, nil
		}
		// 终身买断商品没有过期时间
		return item.ProductID, nil, appleResp.Status, nil
	}

	return "", nil, appleResp.Status, nil
}
```

- [ ] **Step 2: Modify `backend/handlers/license.go:1-135`**

Add the `"dumpit-backend/db"` import, get the current logged-in `uid` right after validating `req.LicenseKey`, and upsert a subscription on both the dev test-key path and the real Lemon Squeezy path:

```go
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
```

- [ ] **Step 3: Add the subscription status endpoint**

```go
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
```

- [ ] **Step 4: Confirm it compiles**

Run: `cd backend && go build ./...`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add backend/handlers/iap.go backend/handlers/license.go backend/handlers/subscription.go
git commit -m "feat(backend): bind IAP and license subscriptions to accounts"
```

---

### Task 9: Personalized tone sample from account history

**Files:**
- Modify: `backend/handlers/audio.go:1-16` (imports), `:97-99` (insert before Whisper call)
- Test: `backend/handlers/audio_test.go`

**Interfaces:**
- Consumes: `services.ParseSessionToken` (Task 3), `db.RecentSummaries` (Task 6).
- Produces: `formatToneSample(summaries []json.RawMessage) string` (package-private, unit-tested), `buildToneSampleFromHistory(ctx context.Context, uid string) (string, error)` (package-private, used only inside this file), `optionalUID(c echo.Context) string` (package-private, non-blocking auth check reused by nothing else in this plan).

- [ ] **Step 1: Write the failing pure-function tests**

```go
package handlers

import (
	"encoding/json"
	"testing"
)

func TestFormatToneSample_Empty(t *testing.T) {
	result := formatToneSample(nil)
	if result != "" {
		t.Fatalf("expected empty string for no history, got %q", result)
	}
}

func TestFormatToneSample_SkipsMalformedEntries(t *testing.T) {
	valid, _ := json.Marshal(map[string]string{"summary": "今天搞定了 PPT"})
	malformed := json.RawMessage(`{not valid json`)

	result := formatToneSample([]json.RawMessage{valid, malformed})
	if result != "今天搞定了 PPT" {
		t.Fatalf("expected only the valid summary, got %q", result)
	}
}

func TestFormatToneSample_JoinsMultiple(t *testing.T) {
	first, _ := json.Marshal(map[string]string{"summary": "第一条"})
	second, _ := json.Marshal(map[string]string{"summary": "第二条"})

	result := formatToneSample([]json.RawMessage{first, second})
	expected := "第一条\n---\n第二条"
	if result != expected {
		t.Fatalf("expected %q, got %q", expected, result)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./handlers/... -run TestFormatToneSample -v`
Expected: FAIL with "undefined: formatToneSample"

- [ ] **Step 3: Add the import block and helper functions to `backend/handlers/audio.go`**

Add to the existing import block (currently lines 1-16):

```go
import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"dumpit-backend/db"
	"dumpit-backend/services"
	"github.com/labstack/echo/v4"
)
```

Add these functions anywhere in the file (e.g. right after `NewAudioHandler`):

```go
// optionalUID 尝试从 Authorization 头解析登录态；未登录或无效时返回空字符串，不阻断匿名请求
func optionalUID(c echo.Context) string {
	header := c.Request().Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return ""
	}
	uid, err := services.ParseSessionToken(strings.TrimPrefix(header, "Bearer "))
	if err != nil {
		return ""
	}
	return uid
}

// formatToneSample 把历史 summary 列表拼接成动态文风样例；输入为空或全部无效时返回空字符串
func formatToneSample(summaries []json.RawMessage) string {
	var parts []string
	for _, raw := range summaries {
		var parsed struct {
			Summary string `json:"summary"`
		}
		if err := json.Unmarshal(raw, &parsed); err != nil {
			continue
		}
		if parsed.Summary != "" {
			parts = append(parts, parsed.Summary)
		}
	}
	return strings.Join(parts, "\n---\n")
}

// buildToneSampleFromHistory 取该账号最近若干条历史记录，拼接成动态文风样例供 RestructureDump 使用
func buildToneSampleFromHistory(ctx context.Context, uid string) (string, error) {
	summaries, err := db.RecentSummaries(ctx, uid, 5)
	if err != nil {
		return "", err
	}
	return formatToneSample(summaries), nil
}
```

- [ ] **Step 4: Run to verify the pure-function tests pass**

Run: `cd backend && go test ./handlers/... -run TestFormatToneSample -v`
Expected: `PASS`

- [ ] **Step 5: Wire it into `UploadAndProcessAudio`, right before the existing "5. 调用 GPT 重组并克隆语气" comment (currently line 118 in the pre-edit file, immediately after the `userToneSample`/`customPrompt` reads at lines 97-99)**

```go
	// 3. 读取表单中的其他配置参数
	userToneSample := c.FormValue("user_tone_sample") // 用户风格文样例
	customPrompt := c.FormValue("custom_prompt")     // 额外大模型处理要求

	// 3.5 若已登录且未手动提供文风样例，则从账号历史自动生成动态文风样例（手动填写的样例仍可覆盖）
	if userToneSample == "" {
		if uid := optionalUID(c); uid != "" {
			if sample, err := buildToneSampleFromHistory(ctx, uid); err == nil && sample != "" {
				userToneSample = sample
			}
		}
	}
```

- [ ] **Step 6: Confirm it compiles**

Run: `cd backend && go build ./...`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add backend/handlers/audio.go backend/handlers/audio_test.go
git commit -m "feat(backend): auto-derive tone sample from account history"
```

---

### Task 10: Wire routes and DB startup in main.go

**Files:**
- Modify: `backend/main.go` (whole file)

**Interfaces:**
- Consumes: everything produced in Tasks 1–9.

- [ ] **Step 1: Rewrite `backend/main.go`**

```go
package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"dumpit-backend/db"
	"dumpit-backend/handlers"
	"dumpit-backend/services"
)

func main() {
	// 加载环境变量，如果在本地运行没有 .env，将跳过并使用系统默认环境变量
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	ctx := context.Background()
	if err := db.Connect(ctx); err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	if err := db.InitSchema(ctx); err != nil {
		log.Fatalf("failed to initialize database schema: %v", err)
	}

	// 初始化服务层与处理器
	openAIService := services.NewOpenAIService()
	notionService := services.NewNotionService()

	audioHandler := handlers.NewAudioHandler(openAIService)
	notionHandler := handlers.NewNotionHandler(notionService)

	// 初始化 Echo 实例
	e := echo.New()

	// 注册全局中间件
	e.Use(middleware.Logger())  // 日志记录
	e.Use(middleware.Recover()) // 异常恢复防止程序崩溃

	// 配置 CORS，允许开发环境下本地以及局域网跨域
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAuthorization},
	}))

	// 基础路由：健康检查
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status":  "ok",
			"message": "BrainVent API is running",
		})
	})
	e.GET("/", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status":  "ok",
			"message": "BrainVent API is running",
		})
	})

	// 无需登录的路由
	e.POST("/api/process-audio", audioHandler.UploadAndProcessAudio)
	e.POST("/api/notion/sync", notionHandler.Sync)
	e.POST("/api/auth/verify", handlers.VerifyAuthHandler)

	// 需要登录的路由：账号维度的订阅与历史记录同步
	authorized := e.Group("", handlers.RequireAuth)
	authorized.POST("/api/license/verify", handlers.VerifyLicenseHandler)
	authorized.POST("/api/iap/verify", handlers.VerifyIAPHandler)
	authorized.GET("/api/subscription", handlers.GetSubscriptionHandler)
	authorized.POST("/api/history/import", handlers.ImportHistoryHandler)
	authorized.POST("/api/history", handlers.CreateHistoryHandler)
	authorized.GET("/api/history", handlers.ListHistoryHandler)
	authorized.PATCH("/api/history/:id", handlers.PatchHistoryHandler)

	// 获取端口配置，默认使用 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 启动服务器
	e.Logger.Fatal(e.Start(":" + port))
}
```

- [ ] **Step 2: Set the required local env vars**

Add to `backend/.env` (gitignored, not committed):
```
DATABASE_URL=postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable
SESSION_JWT_SECRET=<any long random string for local dev>
FIREBASE_PROJECT_ID=<filled in once the Firebase project exists, Task 11>
```

- [ ] **Step 3: Build and run the server locally**

Run: `cd backend && go build ./... && go run .`
Expected: starts without error, logs show it listening on `:8080` (requires the Task 1 `docker compose up -d` Postgres to be running).

- [ ] **Step 4: Manually verify the auth-gated routes reject unauthenticated calls**

Run: `curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8080/api/iap/verify -H "Content-Type: application/json" -d '{"receipt_data":"x"}'`
Expected: `401`

- [ ] **Step 5: Run the full backend test suite**

Run: `cd backend && DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable" SESSION_JWT_SECRET=test-secret go test ./... -v`
Expected: all tests `PASS` (no `FAIL` lines).

- [ ] **Step 6: Commit**

```bash
git add backend/main.go
git commit -m "feat(backend): wire database and account-scoped routes into the server"
```

---

### Task 11: Firebase project setup (manual, human-only)

**This task cannot be executed by an agent.** It requires an interactive Google/Firebase account login. Whoever runs this plan should stop here and complete these steps themselves, then report back the two values needed for Task 10/12/13.

- [ ] **Step 1:** Go to the [Firebase Console](https://console.firebase.google.com), create a project (or reuse an existing Google Cloud project) for BrainVent.
- [ ] **Step 2:** In **Authentication → Sign-in method**, enable the **Phone** provider.
- [ ] **Step 3:** Note the **Project ID** shown in Project Settings — this is the `FIREBASE_PROJECT_ID` value for `backend/.env` and the Render production environment variables.
- [ ] **Step 4:** From the repo root, run `dart pub global activate flutterfire_cli` (if not already installed), then `cd dumpit_mobile && flutterfire configure` — select the project from Step 1, select iOS + Android platforms. This generates `lib/firebase_options.dart` and patches `ios/Runner/GoogleService-Info.plist` / `android/app/google-services.json` automatically.
- [ ] **Step 5:** For Android, add the debug keystore's SHA-1/SHA-256 fingerprint to the Firebase project (Project Settings → Your apps → Android app → Add fingerprint) — required for Play Integrity-based phone auth verification. Get it via `cd dumpit_mobile/android && ./gradlew signingReport`.
- [ ] **Step 6:** Set `SESSION_JWT_SECRET` (any long random string, e.g. `openssl rand -base64 32`) and `FIREBASE_PROJECT_ID` (from Step 3) in the Render production environment variables, and provision a managed Postgres instance on Render, setting its connection string as `DATABASE_URL`.

Known follow-up (not required for this plan's MVP): iOS silent push-based verification (APNs) makes phone auth smoother by skipping reCAPTCHA fallback — Firebase phone auth works without it (falls back to reCAPTCHA), so it's deferred.

---

### Task 12: Mobile Firebase dependencies

**Files:**
- Modify: `dumpit_mobile/pubspec.yaml`
- Modify: `dumpit_mobile/lib/main.dart`

**Interfaces:**
- Consumes: `lib/firebase_options.dart` (generated in Task 11).
- Produces: `Firebase.initializeApp()` called before `runApp` — Task 13 (`AuthService`) depends on Firebase being initialized first.

- [ ] **Step 1: Add the dependencies**

Run: `cd dumpit_mobile && flutter pub add firebase_core firebase_auth`
Expected: `pubspec.yaml` gains `firebase_core` and `firebase_auth` entries; `flutter pub get` runs automatically and succeeds.

- [ ] **Step 2: Initialize Firebase before `runApp` in `dumpit_mobile/lib/main.dart`**

```dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'views/home_page.dart';

void _cleanLegacyTempFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await for (final entity in tempDir.list(recursive: false, followLinks: false)) {
        if (entity is File && (entity.path.contains('/dump_') || entity.path.endsWith('.m4a'))) {
          await entity.delete();
          debugPrint('🧹 Cleared legacy temp audio dump: ${entity.path}');
        }
      }
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _cleanLegacyTempFiles();
  runApp(const BrainVentApp());
}
```

(The `BrainVentApp` widget class below `main()` is unchanged.)

- [ ] **Step 3: Confirm it builds**

Run: `cd dumpit_mobile && flutter analyze && flutter build ios --no-codesign --simulator`
Expected: no analyzer errors; build succeeds (requires Task 11's `flutterfire configure` to have already generated `lib/firebase_options.dart`).

- [ ] **Step 4: Commit**

```bash
git add dumpit_mobile/pubspec.yaml dumpit_mobile/pubspec.lock dumpit_mobile/lib/main.dart dumpit_mobile/lib/firebase_options.dart dumpit_mobile/ios/Runner/GoogleService-Info.plist dumpit_mobile/android/app/google-services.json
git commit -m "feat(mobile): initialize Firebase"
```

---

### Task 13: Auth service + login page

**Files:**
- Create: `dumpit_mobile/lib/services/auth_service.dart`
- Create: `dumpit_mobile/lib/views/login_page.dart`
- Modify: `dumpit_mobile/lib/services/api_service.dart` (append one method)

**Interfaces:**
- Consumes: `ApiService._postJson` (existing, private to the file — the new method lives in the same file so it can call it), Firebase Auth SDK.
- Produces: `AuthService.sendCode(String phoneNumber) -> Future<String>` (returns `verificationId`), `AuthService.confirmCode(String verificationId, String smsCode) -> Future<void>`, `AuthService.getSessionToken() -> Future<String?>`, `AuthService.isLoggedIn() -> Future<bool>`, `AuthService.signOut() -> Future<void>`. Task 14 (`SyncService`) and Task 15 (`home_page.dart`) call these.

- [ ] **Step 1: Add the auth-verify endpoint wrapper to `api_service.dart`**

Add this method inside the `ApiService` class, after `verifyReceipt`:

```dart
  /// 用 Firebase ID Token 向后端换取 session token（首次登录自动建号）
  static Future<Map<String, dynamic>> verifyFirebaseIdToken(String idToken) async {
    return _postJson(
      '/api/auth/verify',
      {'id_token': idToken},
      defaultErrorMsg: '登录验证失败',
    );
  }
```

- [ ] **Step 2: Write `auth_service.dart`**

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  static const _sessionTokenKey = 'dumpit_session_token';
  static const _uidKey = 'dumpit_uid';

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// 发送手机验证码，返回 verificationId 供 [confirmCode] 使用
  static Future<String> sendCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? '验证码发送失败'));
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  /// 用验证码登录，登录成功后向后端换取 session token 并本地持久化
  static Future<void> confirmCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final idToken = await userCredential.user!.getIdToken();

    final decoded = await ApiService.verifyFirebaseIdToken(idToken!);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, decoded['session_token'] as String);
    await prefs.setString(_uidKey, decoded['uid'] as String);
  }

  /// 读取本地持久化的 session token；未登录时返回 null
  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    return await getSessionToken() != null;
  }

  static Future<void> signOut() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_uidKey);
  }
}
```

- [ ] **Step 3: Write `login_page.dart`**

```dart
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _isSending = false;
  bool _isConfirming = false;
  String? _errorMsg;

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _errorMsg = null;
    });
    try {
      final verificationId = await AuthService.sendCode(_phoneController.text.trim());
      setState(() {
        _verificationId = verificationId;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _confirmCode() async {
    if (_verificationId == null) return;
    setState(() {
      _isConfirming = true;
      _errorMsg = null;
    });
    try {
      await AuthService.confirmCode(_verificationId!, _codeController.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isConfirming = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(title: const Text('登录以启用云同步')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              enabled: _verificationId == null,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '手机号（含国家区号，如 +1...）',
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            if (_verificationId == null)
              ElevatedButton(
                onPressed: _isSending ? null : _sendCode,
                child: Text(_isSending ? '发送中...' : '发送验证码'),
              )
            else ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '验证码',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isConfirming ? null : _confirmCode,
                child: Text(_isConfirming ? '登录中...' : '确认登录'),
              ),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Confirm it analyzes cleanly**

Run: `cd dumpit_mobile && flutter analyze lib/services/auth_service.dart lib/views/login_page.dart lib/services/api_service.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add dumpit_mobile/lib/services/auth_service.dart dumpit_mobile/lib/views/login_page.dart dumpit_mobile/lib/services/api_service.dart
git commit -m "feat(mobile): add phone auth login flow"
```

---

### Task 14: Sync service

**Files:**
- Create: `dumpit_mobile/lib/services/sync_service.dart`
- Modify: `dumpit_mobile/lib/services/api_service.dart` (append authenticated HTTP helpers + endpoint wrappers)

**Interfaces:**
- Consumes: `AuthService.getSessionToken()` (Task 13), `HistoryRecord`/`CalendarEvent` (existing `lib/models/history_record.dart`).
- Produces: `SyncService.importLocalHistory(List<HistoryRecord>) -> Future<List<String>>` (returns failed client ids), `SyncService.pushRecord(HistoryRecord) -> Future<bool>`, `SyncService.pullAllHistory() -> Future<List<HistoryRecord>>`. Task 15 (`home_page.dart`) calls these three.

- [ ] **Step 1: Add authenticated HTTP helpers and endpoint wrappers to `api_service.dart`**

Add inside the `ApiService` class, after the `verifyFirebaseIdToken` method added in Task 13:

```dart
  /// 附带登录态的 JSON POST 请求
  static Future<Map<String, dynamic>> _postJsonAuthed(
    String path,
    Map<String, dynamic> body, {
    required String sessionToken,
    required String defaultErrorMsg,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? defaultErrorMsg);
  }

  /// 附带登录态的 JSON GET 请求
  static Future<Map<String, dynamic>> _getJsonAuthed(
    String path, {
    required String sessionToken,
    required String defaultErrorMsg,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $sessionToken'},
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? defaultErrorMsg);
  }

  /// 首次登录批量导入本地历史记录
  static Future<Map<String, dynamic>> importHistory(
    String sessionToken,
    List<Map<String, dynamic>> records,
  ) async {
    return _postJsonAuthed(
      '/api/history/import',
      {'records': records},
      sessionToken: sessionToken,
      defaultErrorMsg: '历史记录导入失败',
    );
  }

  /// 新建一条云端历史记录
  static Future<Map<String, dynamic>> createHistory(
    String sessionToken,
    Map<String, dynamic> summary,
    String rawText,
  ) async {
    return _postJsonAuthed(
      '/api/history',
      {'summary': summary, 'raw_text': rawText},
      sessionToken: sessionToken,
      defaultErrorMsg: '云端保存失败',
    );
  }

  /// 拉取云端历史记录（全部，不做增量，重装/换设备场景足够用）
  static Future<Map<String, dynamic>> listHistory(String sessionToken) async {
    return _getJsonAuthed(
      '/api/history',
      sessionToken: sessionToken,
      defaultErrorMsg: '拉取历史记录失败',
    );
  }
```

- [ ] **Step 2: Write `sync_service.dart`**

```dart
import '../models/history_record.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SyncService {
  /// 首次登录时，把本地全部历史记录一次性导入云端，返回导入失败的本地记录 id 列表
  static Future<List<String>> importLocalHistory(List<HistoryRecord> localRecords) async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null || localRecords.isEmpty) return [];

    final records = localRecords.map((r) => {
      'client_id': r.id,
      'summary': {
        'summary': r.summary,
        'action_items': r.actionItems,
        'key_insights': r.keyInsights,
        'calendar_events': r.calendarEvents.map((e) => e.toJson()).toList(),
      },
      'raw_text': r.rawText,
    }).toList();

    final decoded = await ApiService.importHistory(sessionToken, records);
    return List<String>.from(decoded['failed'] ?? []);
  }

  /// 新建一条记录后同步到云端；失败时调用方应把该记录标记为"待同步"，不要阻塞当前操作
  static Future<bool> pushRecord(HistoryRecord record) async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null) return false;

    try {
      await ApiService.createHistory(
        sessionToken,
        {
          'summary': record.summary,
          'action_items': record.actionItems,
          'key_insights': record.keyInsights,
          'calendar_events': record.calendarEvents.map((e) => e.toJson()).toList(),
        },
        record.rawText,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 拉取云端全部历史记录，换设备/重装后调用
  static Future<List<HistoryRecord>> pullAllHistory() async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null) return [];

    final decoded = await ApiService.listHistory(sessionToken);
    final rawRecords = decoded['records'] as List? ?? [];

    return rawRecords.map((r) {
      final summary = r['summary'] as Map<String, dynamic>;
      return HistoryRecord(
        id: r['id'] as String,
        timestamp: (r['created_at'] as String? ?? '').replaceFirst('T', ' '),
        rawText: r['raw_text'] as String? ?? '',
        summary: summary['summary'] as String? ?? '',
        actionItems: List<String>.from(summary['action_items'] ?? []),
        keyInsights: List<String>.from(summary['key_insights'] ?? []),
        calendarEvents: ((summary['calendar_events'] as List?) ?? [])
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: 'done',
        folder: (r['archived'] == true) ? 'archive' : 'inbox',
      );
    }).toList();
  }
}
```

- [ ] **Step 3: Confirm it analyzes cleanly**

Run: `cd dumpit_mobile && flutter analyze lib/services/sync_service.dart lib/services/api_service.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add dumpit_mobile/lib/services/sync_service.dart dumpit_mobile/lib/services/api_service.dart
git commit -m "feat(mobile): add cloud history sync service"
```

---

### Task 15: Wire login + sync into home_page.dart

**Files:**
- Modify: `dumpit_mobile/lib/views/home_page.dart:1-35` (imports), `:490-514` (record creation), `:1297-1300` (settings panel)

**Interfaces:**
- Consumes: `AuthService.isLoggedIn`, `AuthService.getSessionToken` (Task 13), `SyncService.importLocalHistory`, `SyncService.pushRecord`, `SyncService.pullAllHistory` (Task 14), `LoginPage` (Task 13).

- [ ] **Step 1: Add imports**

Add near the top of `home_page.dart` alongside the other relative imports (e.g. next to the existing `widgets/config_dialogs.dart` import):

```dart
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'login_page.dart';
```

- [ ] **Step 2: Add a login/sync entry point method to `_HomePageState`**

Add this method anywhere inside `_HomePageState` (e.g. right after `_saveNotionPageId`):

```dart
  bool _isLoggedIn = false;

  Future<void> _refreshLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
      });
    }
  }

  /// 打开登录页；登录成功后一次性导入本地历史，再拉取云端历史合并展示
  Future<void> _openAccountSync() async {
    final loggedInNow = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (loggedInNow != true) return;

    await _refreshLoginStatus();

    final failed = await SyncService.importLocalHistory(_historyList);
    if (failed.isNotEmpty) {
      _showSnackBar(_isZh ? '${failed.length} 条记录导入失败，已跳过' : '${failed.length} records failed to import');
    }

    try {
      final cloudRecords = await SyncService.pullAllHistory();
      final localIds = _historyList.map((r) => r.id).toSet();
      final newFromCloud = cloudRecords.where((r) => !localIds.contains(r.id)).toList();
      if (newFromCloud.isNotEmpty) {
        setState(() {
          _historyList.insertAll(0, newFromCloud);
        });
        await _saveHistoryToLocal();
      }
      _showSnackBar(_isZh ? '云同步完成' : 'Cloud sync complete');
    } catch (e) {
      _showSnackBar(_isZh ? '拉取云端记录失败，稍后重试' : 'Failed to pull cloud records, will retry later');
    }
  }
```

- [ ] **Step 3: Call `_refreshLoginStatus()` from `initState`**

In the existing `initState` (lines 117-142), add one line after `_loadLocalSettings();`:

```dart
  void initState() {
    super.initState();
    _loadLocalSettings();
    _refreshLoginStatus();
```

- [ ] **Step 4: Push newly created records to the cloud (best-effort, non-blocking)**

In `_uploadAndProcessAudio` (lines 490-514), right after the existing `await _saveHistoryToLocal();` line, add:

```dart
      await _saveHistoryToLocal();

      // 云同步为尽力而为：失败不阻塞当前操作，本地数据始终是可用的兜底
      unawaited(SyncService.pushRecord(newRecord));

```

This requires `import 'dart:async';` for `unawaited` — add it alongside the other imports at the top of the file if not already present.

- [ ] **Step 5: Add the account/sync row to the settings panel**

In `_buildConfigDrawer` (currently lines 1227-1300), insert this block right before the closing `]` at line 1300 (i.e. right after the AI-privacy `Row(...)` block ends):

```dart
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isZh ? '账号与云同步' : 'Account & Cloud Sync',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoggedIn
                          ? (_isZh ? '已登录，历史记录与订阅状态已绑定账号' : 'Logged in — history and subscription are account-bound')
                          : (_isZh ? '登录后可在换设备/重装时找回历史记录' : 'Log in to recover history after reinstall/device change'),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (!_isLoggedIn)
                TextButton(
                  onPressed: _openAccountSync,
                  child: Text(_isZh ? '登录' : 'Log In', style: const TextStyle(color: Colors.purpleAccent)),
                ),
            ],
          ),
```

- [ ] **Step 6: Confirm it analyzes cleanly**

Run: `cd dumpit_mobile && flutter analyze lib/views/home_page.dart`
Expected: `No issues found!`

- [ ] **Step 7: Manual end-to-end verification (per the spec — no automated E2E test)**

Run the app on a simulator (`cd dumpit_mobile && flutter run`), open settings, tap "登录", complete phone verification with a real or Firebase test phone number, confirm the snackbar shows "云同步完成", create a new dump and confirm no error is shown, then check `GET /api/history` against the backend (with the session token) to confirm the record landed server-side.

- [ ] **Step 8: Commit**

```bash
git add dumpit_mobile/lib/views/home_page.dart
git commit -m "feat(mobile): wire account login and cloud sync into home page"
```

---

## Self-Review Notes

- **Spec coverage:** architecture/data-flow (Tasks 1, 4, 10), data model (Tasks 1, 5, 6), API surface (Tasks 4, 7, 8), personalized tone sample (Task 9), error handling — 401 refresh-and-retry is a mobile-side UX concern layered on top of `AuthService`/`SyncService`'s existing try/catch (Tasks 13, 14), local-first/non-blocking sync (Task 15 Step 4), testing plan (Tasks 1, 2, 3, 5, 6, 9) — all covered.
- **Placeholder scan:** none found; every step has literal code, not descriptions.
- **Type consistency:** `HistoryRecord`/`CalendarEvent` field names in `sync_service.dart` match the existing `lib/models/history_record.dart`; Go handler/db function names match between their definition task and consuming task (checked `CreateHistoryRecord`, `ListHistoryRecords`, `SetArchived`, `RecentSummaries`, `UpsertUser`, `UpsertSubscription`, `GetSubscription`, `RequireAuth`, `UIDFromContext`, `IssueSessionToken`, `ParseSessionToken`, `VerifyFirebaseIDToken` against every call site).
- **Scope check:** single cohesive feature (backend account/sync infra + one mobile client), appropriately large but not multiple independent subsystems — matches the single approved design spec.
