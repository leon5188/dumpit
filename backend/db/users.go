package db

import "context"

// UpsertUser 以手机号作为业务主键做 upsert：同一手机号无论对应哪个 Firebase uid，
// 都落到同一行，避免 phone_number UNIQUE 约束冲突。已存在则更新 uid/email（保留原 created_at）。
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

	// 优先按手机号冲突仲裁；手机号为空时退化为按 uid 仲裁（理论不会发生，uid 恒非空）。
	conflictTarget := "uid"
	if phoneNumber != "" {
		conflictTarget = "phone_number"
	}

	_, err := Pool.Exec(ctx, `
		INSERT INTO users (uid, phone_number, email)
		VALUES ($1, $2, $3)
		ON CONFLICT (`+conflictTarget+`) DO UPDATE SET
			uid = EXCLUDED.uid,
			phone_number = EXCLUDED.phone_number,
			email = EXCLUDED.email
	`, uid, phone, mail)
	return err
}
