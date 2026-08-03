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
