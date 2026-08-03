package db

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

// Connect 建立到 DATABASE_URL 指向的 Postgres 的连接池
func Connect(ctx context.Context) error {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return fmt.Errorf("DATABASE_URL is not configured")
	}

	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return fmt.Errorf("failed to connect to postgres: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("failed to ping postgres: %w", err)
	}

	Pool = pool
	return nil
}

const schemaSQL = `
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
	uid TEXT PRIMARY KEY,
	phone_number TEXT UNIQUE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
	uid TEXT PRIMARY KEY REFERENCES users(uid),
	product_id TEXT NOT NULL,
	expires_at TIMESTAMPTZ,
	source TEXT NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS history_records (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	uid TEXT NOT NULL REFERENCES users(uid),
	summary JSONB NOT NULL,
	raw_text TEXT NOT NULL DEFAULT '',
	created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	archived BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_history_records_uid_created_at ON history_records(uid, created_at DESC);
`

// InitSchema 幂等地创建所需的表/索引，可重复执行
func InitSchema(ctx context.Context) error {
	if _, err := Pool.Exec(ctx, schemaSQL); err != nil {
		return fmt.Errorf("failed to init schema: %w", err)
	}
	return nil
}
