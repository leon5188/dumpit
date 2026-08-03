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
