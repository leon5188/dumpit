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
	if err := UpsertUser(ctx, uid, "+10000000000", ""); err != nil {
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
