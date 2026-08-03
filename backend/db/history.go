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
