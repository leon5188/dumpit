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
