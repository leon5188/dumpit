package db

import "context"

// UpsertUser 若 uid 不存在则插入新用户；已存在则更新手机号/邮箱（保留原 created_at）。
// phoneNumber/email 为空字符串时写 NULL 而不是空字符串——两者都有 UNIQUE 约束，
// 多行空字符串会互相冲突，多行 NULL 则不会。
func UpsertUser(ctx context.Context, uid string, phoneNumber string, email string) error {
	var phone, mail *string
	if phoneNumber != "" {
		phone = &phoneNumber
	}
	if email != "" {
		mail = &email
	}

	_, err := Pool.Exec(ctx, `
		INSERT INTO users (uid, phone_number, email)
		VALUES ($1, $2, $3)
		ON CONFLICT (uid) DO UPDATE SET phone_number = EXCLUDED.phone_number, email = EXCLUDED.email
	`, uid, phone, mail)
	return err
}
