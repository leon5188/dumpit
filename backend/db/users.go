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
