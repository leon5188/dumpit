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
