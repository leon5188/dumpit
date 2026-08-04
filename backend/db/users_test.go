package db

import (
	"context"
	"os"
	"testing"
)

func TestUpsertUser_EmptyPhoneAndEmailDoNotCollide(t *testing.T) {
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

	uidA := "test-uid-empty-a"
	uidB := "test-uid-empty-b"

	if err := UpsertUser(ctx, uidA, "", ""); err != nil {
		t.Fatalf("UpsertUser for uidA failed: %v", err)
	}
	if err := UpsertUser(ctx, uidB, "", ""); err != nil {
		t.Fatalf("UpsertUser for uidB failed (two empty phone/email rows should not collide on UNIQUE): %v", err)
	}

	if _, err := Pool.Exec(ctx, "DELETE FROM users WHERE uid IN ($1, $2)", uidA, uidB); err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}
