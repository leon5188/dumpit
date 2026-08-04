# Web 账号体系 + 云同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 web 端（`frontend/`）加上 Firebase Email Link 登录，登录后历史记录与订阅状态云端持久化，并用登录态替代现有的 license key 手动解锁流程。

**Architecture:** web 端接入 Firebase Web SDK（Email Link 登录），换取 Firebase ID Token 后调用后端已有的通用 `POST /api/auth/verify` 拿 session token；history/subscription 走后端已有的 `/api/history`、`/api/history/import`、`/api/subscription` 接口。web 的 Firebase UID 与 mobile 的手机号 UID 是两套独立身份，不互通。后端只需两处小改动：`FirebaseClaims` 增加 `email` 解析、`users` 表增加 `email` 列。

**Tech Stack:** Next.js 16 + React 19（现有）、`firebase`（新增 npm 依赖，Web SDK v9+ 模块化 API）、Go 1.25 + Echo v4（现有，仅小幅修改）。

## Global Constraints

- 不新增自动化前端测试——`frontend/` 目前没有任何测试基础设施，本次也遵循 mobile 分支已定的约定（人工验证，不写自动化端到端测试）。
- 后端 `db/db_test.go`、`db/subscriptions_test.go`、`db/history_test.go` 这类需要真实 Postgres 的集成测试沿用现有约定：`DATABASE_URL` 未设置时 `t.Skip`。
- 不改动 `backend/handlers/license.go` 或 mobile 端的 license key 流程——本计划范围仅去掉 **web 页面上**的 license key UI。
- web 与 mobile 账号不互通、不做绑定/合并，这是本计划明确接受的架构限制（见 design spec）。
- 所有新增 fetch 调用必须走 `lib/api.ts` 里统一的 `getBackendUrl`/`postJson`/`postJsonAuthed`/`getJsonAuthed`，不要在各文件里各写一套。

---

## File Structure

**Backend (modified):**
- `backend/services/firebase_auth.go` — `FirebaseClaims` 增加 `Email` 字段，`VerifyFirebaseIDToken` 多返回一个 `email string`
- `backend/services/firebase_auth_test.go` — 适配新的 4 个返回值
- `backend/db/db.go` — schema 增加 `users.email` 列
- `backend/db/users.go` — `UpsertUser` 增加 `email` 参数，且用 NULL（而不是空字符串）写入未提供的字段，避免 UNIQUE 约束在多个空字符串之间冲突
- `backend/db/subscriptions_test.go`、`backend/db/history_test.go` — 适配 `UpsertUser` 新签名
- `backend/handlers/auth.go` — 透传 email 给 `UpsertUser`

**Frontend (new):**
- `frontend/src/app/app/lib/api.ts` — `getBackendUrl`（从 `page.tsx` 搬出）+ `postJson`/`postJsonAuthed`/`getJsonAuthed` 三个 fetch 封装
- `frontend/src/app/app/lib/firebase.ts` — Firebase Web SDK 初始化（复用 mobile 端已注册的同一个 Firebase 项目的 Web App 配置，无需在 Firebase Console 新建 App）
- `frontend/src/app/app/lib/auth.ts` — `sendLoginLink`/`completeLoginLinkIfPresent`/`logout`/`getSessionToken`/`hasSessionToken`
- `frontend/src/app/app/lib/sync.ts` — `importLocalHistory`/`pushRecord`/`pullAllHistory`/`fetchSubscription`
- `frontend/src/app/app/lib/types.ts` — `HistoryRecord` 接口（从 `page.tsx` 搬出，供 `page.tsx` 和 `sync.ts` 共用）

**Frontend (modified):**
- `frontend/package.json` — 新增 `firebase` 依赖
- `frontend/src/app/app/page.tsx` — 删除本地 `getBackendUrl` 定义和 `HistoryRecord` 接口定义（改为 import），删除 license key 相关 state/函数/UI，新增登录态 UI 和账号同步逻辑

---

### Task 1: 后端 —— Firebase ID Token 解析 email

**Files:**
- Modify: `backend/services/firebase_auth.go`
- Modify: `backend/services/firebase_auth_test.go`

**Interfaces:**
- Produces: `VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, email string, err error)` —— Task 3（`handlers/auth.go`）会调用这个新签名。

- [ ] **Step 1: 给 `FirebaseClaims` 加 email 字段**

在 `backend/services/firebase_auth.go` 里，把：

```go
type FirebaseClaims struct {
	PhoneNumber string `json:"phone_number"`
	jwt.RegisteredClaims
}
```

改成：

```go
type FirebaseClaims struct {
	PhoneNumber string `json:"phone_number"`
	Email       string `json:"email"`
	jwt.RegisteredClaims
}
```

- [ ] **Step 2: 修改 `VerifyFirebaseIDToken` 的返回值**

把函数签名从：

```go
func VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, err error) {
```

改成：

```go
func VerifyFirebaseIDToken(idToken string, projectID string) (uid string, phoneNumber string, email string, err error) {
```

函数体里所有 `return "", "", ...` 改成 `return "", "", "", ...`，最后一行：

```go
	return claims.Subject, claims.PhoneNumber, claims.Email, nil
```

- [ ] **Step 3: 更新现有测试文件的调用**

`backend/services/firebase_auth_test.go` 目前是：

```go
package services

import "testing"

func TestVerifyFirebaseIDToken_MalformedToken(t *testing.T) {
	_, _, err := VerifyFirebaseIDToken("not-a-jwt", "some-project-id")
	if err == nil {
		t.Fatal("expected error for malformed token, got nil")
	}
}
```

改成：

```go
package services

import "testing"

func TestVerifyFirebaseIDToken_MalformedToken(t *testing.T) {
	_, _, _, err := VerifyFirebaseIDToken("not-a-jwt", "some-project-id")
	if err == nil {
		t.Fatal("expected error for malformed token, got nil")
	}
}
```

- [ ] **Step 4: 编译并跑测试确认通过**

Run: `cd backend && go build ./... && go test ./services/...`
Expected: 编译通过，`TestVerifyFirebaseIDToken_MalformedToken` PASS（`handlers/auth.go` 此时还没改，编译会在 `handlers` 包报错——这是预期的，Task 3 会修；只需确认 `services` 包本身编译测试通过：`go build ./services/... && go test ./services/...`）

- [ ] **Step 5: Commit**

```bash
git add backend/services/firebase_auth.go backend/services/firebase_auth_test.go
git commit -m "feat(backend): parse email claim from Firebase ID token"
```

---

### Task 2: 后端 —— users 表增加 email 列，UpsertUser 支持 email

**Files:**
- Modify: `backend/db/db.go`
- Modify: `backend/db/users.go`
- Modify: `backend/db/subscriptions_test.go`
- Modify: `backend/db/history_test.go`

**Interfaces:**
- Consumes: 无（独立于 Task 1）
- Produces: `UpsertUser(ctx context.Context, uid string, phoneNumber string, email string) error` —— Task 3（`handlers/auth.go`）会调用这个新签名。

- [ ] **Step 1: schema 里给 users 表加 email 列（幂等 ALTER，兼容已部署的生产库）**

在 `backend/db/db.go` 的 `schemaSQL` 常量里，`CREATE TABLE IF NOT EXISTS users (...)` 语句后面加一行：

```go
const schemaSQL = `
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
	uid TEXT PRIMARY KEY,
	phone_number TEXT UNIQUE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;

CREATE TABLE IF NOT EXISTS subscriptions (
```

（`CREATE TABLE IF NOT EXISTS` 对已存在的生产表不会补列，所以必须单独用 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 才能让已部署的 Render 数据库也拿到这一列。）

- [ ] **Step 2: 改 `UpsertUser` 支持 email，且用 NULL 而不是空字符串**

`backend/db/users.go` 当前是：

```go
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
```

改成：

```go
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
```

- [ ] **Step 3: 更新调用 `UpsertUser` 的两个测试文件**

`backend/db/subscriptions_test.go` 第 25 行，把：

```go
	if err := UpsertUser(ctx, uid, "+10000000000"); err != nil {
```

改成：

```go
	if err := UpsertUser(ctx, uid, "+10000000000", ""); err != nil {
```

`backend/db/history_test.go` 第 25 行，把：

```go
	if err := UpsertUser(ctx, uid, "+10000000001"); err != nil {
```

改成：

```go
	if err := UpsertUser(ctx, uid, "+10000000001", ""); err != nil {
```

- [ ] **Step 4: 跑数据库集成测试确认通过（需要本地 Postgres）**

Run:
```bash
cd backend
docker compose up -d
export DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable"
go test ./db/... -v
```
Expected: `TestConnectAndInitSchema`、`TestUpsertSubscription_UpdatesNotDuplicates`、以及 history 相关测试全部 PASS（`InitSchema` 会执行新的 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS email` 语句）

- [ ] **Step 5: Commit**

```bash
git add backend/db/db.go backend/db/users.go backend/db/subscriptions_test.go backend/db/history_test.go
git commit -m "feat(backend): add email column to users table, thread through UpsertUser"
```

---

### Task 3: 后端 —— 把 email 接到登录 handler

**Files:**
- Modify: `backend/handlers/auth.go`

**Interfaces:**
- Consumes: `services.VerifyFirebaseIDToken`（Task 1 产出的 4 返回值签名）、`db.UpsertUser`（Task 2 产出的 4 参数签名）

- [ ] **Step 1: 更新 `VerifyAuthHandler` 里的调用**

`backend/handlers/auth.go` 里把：

```go
	uid, phoneNumber, err := services.VerifyFirebaseIDToken(req.IDToken, projectID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid firebase id token: " + err.Error()})
	}

	if err := db.UpsertUser(c.Request().Context(), uid, phoneNumber); err != nil {
```

改成：

```go
	uid, phoneNumber, email, err := services.VerifyFirebaseIDToken(req.IDToken, projectID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid firebase id token: " + err.Error()})
	}

	if err := db.UpsertUser(c.Request().Context(), uid, phoneNumber, email); err != nil {
```

- [ ] **Step 2: 全量编译确认整个后端可以构建**

Run: `cd backend && go build ./... && go vet ./...`
Expected: 无报错（这一步会验证 Task 1/2/3 三处签名改动互相匹配）

- [ ] **Step 3: 跑一次全量测试**

Run: `cd backend && go test ./...`
Expected: 全部 PASS（没设置 `DATABASE_URL` 的话数据库相关测试会 SKIP，这是预期行为）

- [ ] **Step 4: Commit**

```bash
git add backend/handlers/auth.go
git commit -m "feat(backend): thread email through /api/auth/verify"
```

---

### Task 4: 前端 —— lib/api.ts、lib/types.ts（基础设施，不涉及登录逻辑）

**Files:**
- Create: `frontend/src/app/app/lib/api.ts`
- Create: `frontend/src/app/app/lib/types.ts`
- Modify: `frontend/src/app/app/page.tsx`

**Interfaces:**
- Produces: `getBackendUrl(path: string): string`、`postJson(path, body, defaultErrorMsg): Promise<any>`、`postJsonAuthed(path, body, sessionToken, defaultErrorMsg): Promise<any>`、`getJsonAuthed(path, sessionToken, defaultErrorMsg): Promise<any>`（Task 5/6 会用到这四个）；`HistoryRecord` 类型（Task 5/6 会用到）

- [ ] **Step 1: 创建 `lib/types.ts`**

```ts
import { CalendarEvent } from "../locales";

export interface HistoryRecord {
	id: string;
	timestamp: string;
	rawText: string;
	summary: string;
	actionItems: string[];
	keyInsights: string[];
	calendarEvents: CalendarEvent[];
	status?: "done" | "offline_pending" | "syncing" | "error";
	folder?: "inbox" | "archive" | "trash";
	offlineAudio?: string;
	toneSample?: string;
	prompt?: string;
}
```

- [ ] **Step 2: 创建 `lib/api.ts`**

```ts
// 🌐 动态计算后端基准 API URL，优先使用用户配置的自定义基准地址，兼容本地/局域网及 HTTPS 部署
export function getBackendUrl(path: string): string {
	if (typeof window !== "undefined") {
		const savedUrl = localStorage.getItem("dumpit_backend_url");
		if (savedUrl) {
			const cleanBase = savedUrl.endsWith("/") ? savedUrl.slice(0, -1) : savedUrl;
			return `${cleanBase}${path}`;
		}
	}
	const defaultEnvUrl = process.env.NEXT_PUBLIC_API_URL;
	if (defaultEnvUrl) {
		const cleanEnv = defaultEnvUrl.endsWith("/") ? defaultEnvUrl.slice(0, -1) : defaultEnvUrl;
		return `${cleanEnv}${path}`;
	}
	if (typeof window === "undefined") return `http://localhost:8080${path}`;
	if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
		return `http://localhost:8080${path}`;
	}
	const protocol = window.location.protocol;
	const hostname = window.location.hostname;
	return `${protocol}//${hostname}:8080${path}`;
}

async function parseJsonOrThrow(res: Response, defaultErrorMsg: string): Promise<any> {
	const decoded = await res.json();
	if (res.ok) return decoded;
	throw new Error(decoded.error || defaultErrorMsg);
}

export async function postJson(path: string, body: unknown, defaultErrorMsg: string): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}

export async function postJsonAuthed(
	path: string,
	body: unknown,
	sessionToken: string,
	defaultErrorMsg: string
): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Authorization: `Bearer ${sessionToken}`,
		},
		body: JSON.stringify(body),
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}

export async function getJsonAuthed(path: string, sessionToken: string, defaultErrorMsg: string): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		headers: { Authorization: `Bearer ${sessionToken}` },
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}
```

- [ ] **Step 3: `page.tsx` 改用新模块里的 `getBackendUrl`/`HistoryRecord`**

在 `frontend/src/app/app/page.tsx` 顶部 import 区域（第 3-8 行）加：

```ts
import { getBackendUrl } from "./lib/api";
import { HistoryRecord } from "./lib/types";
```

删除文件里原来的 `HistoryRecord` 接口定义（第 10-24 行）。

删除文件里原来的 `getBackendUrl` 函数定义（第 27-49 行，`const getBackendUrl = (path: string): string => { ... };`）。

- [ ] **Step 4: 确认前端类型检查通过**

Run: `cd frontend && npx tsc --noEmit`
Expected: 无报错

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/app/lib/api.ts frontend/src/app/app/lib/types.ts frontend/src/app/app/page.tsx
git commit -m "refactor(frontend): extract getBackendUrl and HistoryRecord into lib/"
```

---

### Task 5: 前端 —— Firebase SDK 初始化 + 登录/登出（lib/firebase.ts、lib/auth.ts）

**Files:**
- Create: `frontend/src/app/app/lib/firebase.ts`
- Create: `frontend/src/app/app/lib/auth.ts`
- Modify: `frontend/package.json`

**Interfaces:**
- Consumes: `postJson`（Task 4 产出）
- Produces: `getSessionToken(): string | null`、`hasSessionToken(): boolean`、`sendLoginLink(email: string): Promise<void>`、`completeLoginLinkIfPresent(): Promise<boolean>`、`logout(): Promise<void>` —— Task 6 会用到这五个。

- [ ] **Step 1: 安装 Firebase Web SDK**

Run: `cd frontend && npm install firebase`
Expected: `package.json`/`package-lock.json` 里新增 `firebase` 依赖

- [ ] **Step 2: 创建 `lib/firebase.ts`**

这是 mobile 端（`dumpit_mobile/lib/firebase_options.dart`）已经在同一个 Firebase 项目（`brainvent-9704a`）里注册好的 Web App 配置，直接复用，不需要在 Firebase Console 再新建一个 App：

```ts
import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
	apiKey: "AIzaSyCUJreGDIJ_AkUeidNZgIov5-PK2VnyfJo",
	authDomain: "brainvent-9704a.firebaseapp.com",
	projectId: "brainvent-9704a",
	storageBucket: "brainvent-9704a.firebasestorage.app",
	messagingSenderId: "850734062900",
	appId: "1:850734062900:web:e1fb5b7f88e4d82a51d961",
	measurementId: "G-1C4E3302FQ",
};

export const firebaseApp = getApps().length ? getApp() : initializeApp(firebaseConfig);
export const firebaseAuth = getAuth(firebaseApp);
```

- [ ] **Step 3: 创建 `lib/auth.ts`**

```ts
import {
	sendSignInLinkToEmail,
	isSignInWithEmailLink,
	signInWithEmailLink,
	signOut as firebaseSignOut,
} from "firebase/auth";
import { firebaseAuth } from "./firebase";
import { postJson } from "./api";

const SESSION_TOKEN_KEY = "dumpit_session_token";
const PENDING_EMAIL_KEY = "dumpit_pending_login_email";

export function getSessionToken(): string | null {
	if (typeof window === "undefined") return null;
	return localStorage.getItem(SESSION_TOKEN_KEY);
}

export function hasSessionToken(): boolean {
	return getSessionToken() !== null;
}

// 发送登录链接到邮箱；邮箱同时存本地，供同设备点击链接回跳时使用
export async function sendLoginLink(email: string): Promise<void> {
	const actionCodeSettings = {
		url: `${window.location.origin}/app`,
		handleCodeInApp: true,
	};
	await sendSignInLinkToEmail(firebaseAuth, email, actionCodeSettings);
	localStorage.setItem(PENDING_EMAIL_KEY, email);
}

// 检测当前 URL 是否是登录邮件里的链接；命中则完成登录并返回 true，不是则返回 false。
// 只支持同设备/同浏览器打开链接——本地找不到 pending email 时视为错误，不做跨设备补录邮箱的 UI。
export async function completeLoginLinkIfPresent(): Promise<boolean> {
	if (!isSignInWithEmailLink(firebaseAuth, window.location.href)) return false;

	const email = localStorage.getItem(PENDING_EMAIL_KEY);
	if (!email) {
		throw new Error("请在发送登录链接的同一浏览器中打开该链接");
	}

	const credential = await signInWithEmailLink(firebaseAuth, email, window.location.href);
	const idToken = await credential.user.getIdToken();

	const decoded = await postJson("/api/auth/verify", { id_token: idToken }, "登录验证失败");
	localStorage.setItem(SESSION_TOKEN_KEY, decoded.session_token as string);
	localStorage.removeItem(PENDING_EMAIL_KEY);

	window.history.replaceState({}, "", window.location.pathname);
	return true;
}

export async function logout(): Promise<void> {
	await firebaseSignOut(firebaseAuth);
	localStorage.removeItem(SESSION_TOKEN_KEY);
}
```

- [ ] **Step 4: 确认前端类型检查通过**

Run: `cd frontend && npx tsc --noEmit`
Expected: 无报错

- [ ] **Step 5: Commit**

```bash
git add frontend/package.json frontend/package-lock.json frontend/src/app/app/lib/firebase.ts frontend/src/app/app/lib/auth.ts
git commit -m "feat(frontend): add Firebase Email Link login (lib/firebase.ts, lib/auth.ts)"
```

---

### Task 6: 前端 —— 历史记录云同步（lib/sync.ts）

**Files:**
- Create: `frontend/src/app/app/lib/sync.ts`

**Interfaces:**
- Consumes: `getSessionToken`（Task 5）、`postJson`/`postJsonAuthed`/`getJsonAuthed`（Task 4）、`HistoryRecord`（Task 4）
- Produces: `importLocalHistory(records: HistoryRecord[]): Promise<ImportResult>`、`pushRecord(record: HistoryRecord): Promise<void>`、`pullAllHistory(): Promise<HistoryRecord[]>`、`fetchSubscription(): Promise<boolean>` —— Task 7 会用到这四个。

- [ ] **Step 1: 创建 `lib/sync.ts`**

```ts
import { getSessionToken } from "./auth";
import { postJson, postJsonAuthed, getJsonAuthed } from "./api";
import { HistoryRecord } from "./types";

export interface ImportResult {
	failedIds: string[];
	idMapping: Record<string, string>;
}

function toBackendSummary(record: HistoryRecord) {
	return {
		summary: record.summary,
		action_items: record.actionItems,
		key_insights: record.keyInsights,
		calendar_events: record.calendarEvents,
	};
}

// 首次登录时，把本地全部历史记录一次性导入云端
export async function importLocalHistory(records: HistoryRecord[]): Promise<ImportResult> {
	const sessionToken = getSessionToken();
	if (!sessionToken || records.length === 0) return { failedIds: [], idMapping: {} };

	const payload = records.map((r) => ({
		client_id: r.id,
		summary: toBackendSummary(r),
		raw_text: r.rawText,
	}));

	const decoded = await postJsonAuthed(
		"/api/history/import",
		{ records: payload },
		sessionToken,
		"历史记录导入失败"
	);

	const failedIds: string[] = decoded.failed || [];
	const idMapping: Record<string, string> = {};
	for (const entry of decoded.imported || []) {
		idMapping[entry.client_id] = entry.server_id;
	}
	return { failedIds, idMapping };
}

// 新建一条记录后同步到云端；失败静默，调用方不应因此阻塞当前操作
export async function pushRecord(record: HistoryRecord): Promise<void> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return;
	try {
		await postJsonAuthed(
			"/api/history",
			{ summary: toBackendSummary(record), raw_text: record.rawText },
			sessionToken,
			"云端保存失败"
		);
	} catch (err) {
		console.warn("pushRecord failed", err);
	}
}

// 拉取云端全部历史记录（全量，不做增量，重装/换设备场景足够用）
export async function pullAllHistory(): Promise<HistoryRecord[]> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return [];

	const decoded = await getJsonAuthed("/api/history", sessionToken, "拉取历史记录失败");
	const rawRecords: any[] = decoded.records || [];

	return rawRecords.map((r) => ({
		id: r.id as string,
		timestamp: ((r.created_at as string) || "").replace("T", " "),
		rawText: (r.raw_text as string) || "",
		summary: r.summary?.summary || "",
		actionItems: r.summary?.action_items || [],
		keyInsights: r.summary?.key_insights || [],
		calendarEvents: r.summary?.calendar_events || [],
		status: "done" as const,
		folder: r.archived ? ("archive" as const) : ("inbox" as const),
	}));
}

// 拉取当前账号的订阅状态；只做恢复，返回 false 时调用方不应吊销本地已有的会员状态
export async function fetchSubscription(): Promise<boolean> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return false;
	try {
		const decoded = await getJsonAuthed("/api/subscription", sessionToken, "拉取订阅状态失败");
		if (decoded.subscribed !== true) return false;
		const expiresAt = decoded.expires_at as string | null;
		return !expiresAt || new Date(expiresAt) > new Date();
	} catch {
		return false;
	}
}
```

- [ ] **Step 2: 确认前端类型检查通过**

Run: `cd frontend && npx tsc --noEmit`
Expected: 无报错

- [ ] **Step 3: Commit**

```bash
git add frontend/src/app/app/lib/sync.ts
git commit -m "feat(frontend): add cloud history sync (lib/sync.ts)"
```

---

### Task 7: 前端 —— 在 page.tsx 里接入登录 UI 与账号同步，去掉 license key

**Files:**
- Modify: `frontend/src/app/app/page.tsx`

**Interfaces:**
- Consumes: `sendLoginLink`/`completeLoginLinkIfPresent`/`logout`/`hasSessionToken`（Task 5）、`importLocalHistory`/`pushRecord`/`pullAllHistory`/`fetchSubscription`（Task 6）

- [ ] **Step 1: import 新模块**

在 `page.tsx` 顶部 import 区域加：

```ts
import { sendLoginLink, completeLoginLinkIfPresent, logout, hasSessionToken } from "./lib/auth";
import { importLocalHistory, pushRecord, pullAllHistory, fetchSubscription } from "./lib/sync";
```

- [ ] **Step 2: 删除 license key 相关 state，新增登录相关 state**

把：

```ts
	const [licenseKey, setLicenseKey] = useState("");
```

删掉，改为：

```ts
	const [isLoggedIn, setIsLoggedIn] = useState(false);
	const [loginEmail, setLoginEmail] = useState("");
```

（`isPremium`/`setIsPremium` 保留不动，只是不再由 license key 驱动。）

- [ ] **Step 3: 删除 init effect 里读 license key / is_premium 的两段**

在现有的 init `useEffect`（第 103-148 行）里，删掉这两段：

```ts
			const savedLicenseKey = localStorage.getItem("dumpit_license_key");
			if (savedLicenseKey) setLicenseKey(savedLicenseKey);
```

```ts
			const savedIsPremium = localStorage.getItem("dumpit_is_premium");
			if (savedIsPremium === "true") setIsPremium(true);
```

- [ ] **Step 4: 删除 `verifyLicense` 函数**

删掉整个 `verifyLicense` 函数（第 212-245 行，从 `// 🔒 调用后端核销激活码` 注释到函数结尾）。

- [ ] **Step 5: 新增登录完成检测 + 账号同步逻辑**

在 `showToast` 函数定义之后（第 618 行之后），加一个新的 `useEffect` 和一个 `runAccountSync` 辅助函数：

```ts
	// 账号同步：导入本地记录、拉取云端记录合并、恢复订阅状态。
	// 直接读 localStorage 里的 dumpit_history 而不是读 historyList state——
	// 这个函数在挂载时的 effect 里调用，此时 historyList state 可能还没被
	// 另一个 init effect 从 localStorage 加载完，读 state 会拿到过时的空数组。
	const runAccountSync = async () => {
		const raw = localStorage.getItem("dumpit_history");
		const localRecords: HistoryRecord[] = raw ? JSON.parse(raw) : [];

		const importResult = await importLocalHistory(localRecords);
		if (importResult.failedIds.length > 0) {
			showToast(
				lang === "zh"
					? `${importResult.failedIds.length} 条记录导入失败，已跳过`
					: `${importResult.failedIds.length} records failed to import`
			);
		}

		let mergedHistory = localRecords;
		if (Object.keys(importResult.idMapping).length > 0) {
			let newActiveId: string | null = null;
			mergedHistory = localRecords.map((r) => {
				const serverId = importResult.idMapping[r.id];
				if (!serverId) return r;
				if (activeRecordId === r.id) newActiveId = serverId;
				return { ...r, id: serverId };
			});
			if (newActiveId) setActiveRecordId(newActiveId);
		}

		try {
			const cloudRecords = await pullAllHistory();
			const localIds = new Set(mergedHistory.map((r) => r.id));
			const newFromCloud = cloudRecords.filter((r) => !localIds.has(r.id));
			mergedHistory = [...newFromCloud, ...mergedHistory];
			showToast(lang === "zh" ? "云同步完成" : "Cloud sync complete");
		} catch {
			showToast(lang === "zh" ? "拉取云端记录失败，稍后重试" : "Failed to pull cloud records, will retry later");
		}

		setHistoryList(mergedHistory);
		localStorage.setItem("dumpit_history", JSON.stringify(mergedHistory));

		const premium = await fetchSubscription();
		if (premium) setIsPremium(true); // 只做恢复，不吊销本地已有的会员状态
	};

	// 挂载时检测邮件登录链接回跳；命中或本来就已登录都会触发一次账号同步
	useEffect(() => {
		(async () => {
			try {
				const justLoggedIn = await completeLoginLinkIfPresent();
				if (justLoggedIn) setIsLoggedIn(true);
			} catch (err: any) {
				showToast(err.message || (lang === "zh" ? "⚠️ 登录链接无效或已过期" : "⚠️ Invalid or expired login link"));
				return;
			}
			if (hasSessionToken()) {
				setIsLoggedIn(true);
				await runAccountSync();
			}
		})();
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, []);

	const handleSendLoginLink = async () => {
		if (!loginEmail) {
			showToast(lang === "zh" ? "⚠️ 请先输入邮箱" : "⚠️ Please enter your email first");
			return;
		}
		try {
			await sendLoginLink(loginEmail);
			showToast(lang === "zh" ? "📧 登录链接已发送，请查收邮箱" : "📧 Login link sent, check your email");
		} catch (err: any) {
			showToast(lang === "zh" ? `⚠️ 发送失败: ${err.message}` : `⚠️ Failed to send: ${err.message}`);
		}
	};

	const handleLogout = async () => {
		await logout();
		setIsLoggedIn(false);
		setIsPremium(false);
		showToast(lang === "zh" ? "已登出" : "Logged out");
	};
```

- [ ] **Step 6: 新建记录后 push 到云端**

在 `uploadAndProcess` 函数里（第 458-461 行附近），把：

```ts
			const updatedHistory = [newRecord, ...historyList].slice(0, 50);
			setHistoryList(updatedHistory);
			localStorage.setItem("dumpit_history", JSON.stringify(updatedHistory));
			setActiveRecordId(newRecord.id);

			setStatus("done");
```

改成：

```ts
			const updatedHistory = [newRecord, ...historyList].slice(0, 50);
			setHistoryList(updatedHistory);
			localStorage.setItem("dumpit_history", JSON.stringify(updatedHistory));
			setActiveRecordId(newRecord.id);
			void pushRecord(newRecord);

			setStatus("done");
```

- [ ] **Step 7: 替换配置抽屉里的 license key 输入框为登录 UI**

在 `page.tsx` 里找到这一段（约第 860-879 行）：

```tsx
								<div className="input-group" style={{ marginTop: "10px" }}>
									<label htmlFor="license-key" style={{ color: "#FBBF24", fontWeight: "bold" }}>{lang === "zh" ? "🔑 BrainVent. 黄金会员激活码 (License Key)" : "🔑 BrainVent. Premium License Key"}</label>
									<div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
										<input
											id="license-key"
											type="password"
											className="input-field"
											placeholder="e.g. LSQ-..."
											value={licenseKey}
											onChange={(e) => setLicenseKey(e.target.value)}
											style={{ flex: 1, background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.08)", color: "#fff", padding: "0.5rem", borderRadius: "8px", outline: "none", fontSize: "12px" }}
										/>
										<button 
											onClick={verifyLicense}
											style={{ background: "linear-gradient(90deg, #FBBF24 0%, #F59E0B 100%)", color: "#000", border: "none", borderRadius: "8px", padding: "0 1rem", fontSize: "12px", fontWeight: "bold", cursor: "pointer" }}
										>
											{lang === "zh" ? "激活" : "Activate"}
										</button>
									</div>
								</div>
```

替换成：

```tsx
								<div className="input-group" style={{ marginTop: "10px" }}>
									<label style={{ color: "#FBBF24", fontWeight: "bold" }}>
										{lang === "zh" ? "🔑 账号与云同步" : "🔑 Account & Cloud Sync"}
									</label>
									{isLoggedIn ? (
										<div style={{ display: "flex", alignItems: "center", gap: "8px", marginTop: "4px" }}>
											<span style={{ color: "#10B981", fontSize: "12px" }}>
												{lang === "zh" ? "已登录，历史记录与订阅状态已绑定账号" : "Logged in — history and subscription are account-bound"}
											</span>
											<button
												onClick={handleLogout}
												style={{ background: "rgba(255,255,255,0.08)", color: "#fff", border: "none", borderRadius: "8px", padding: "0 1rem", fontSize: "12px", fontWeight: "bold", cursor: "pointer" }}
											>
												{lang === "zh" ? "登出" : "Log Out"}
											</button>
										</div>
									) : (
										<div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
											<input
												id="login-email"
												type="email"
												className="input-field"
												placeholder="you@example.com"
												value={loginEmail}
												onChange={(e) => setLoginEmail(e.target.value)}
												style={{ flex: 1, background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.08)", color: "#fff", padding: "0.5rem", borderRadius: "8px", outline: "none", fontSize: "12px" }}
											/>
											<button
												onClick={handleSendLoginLink}
												style={{ background: "linear-gradient(90deg, #FBBF24 0%, #F59E0B 100%)", color: "#000", border: "none", borderRadius: "8px", padding: "0 1rem", fontSize: "12px", fontWeight: "bold", cursor: "pointer" }}
											>
												{lang === "zh" ? "发送登录链接" : "Send Link"}
											</button>
										</div>
									)}
								</div>
```

- [ ] **Step 8: 更新付费功能的提示文案**

在 `syncToNotion` 函数里（约第 170-173 行），把：

```ts
		if (!isPremium) {
			alert(lang === "zh" ? "🔒 提示: 一键同步到 Notion 是黄金会员专属特权！请在下方偏好配置中填写激活码激活授权。" : "🔒 Notice: Notion 1-Click Sync is a Premium privilege! Please activate your license key in settings.");
			return;
		}
```

改成：

```ts
		if (!isPremium) {
			alert(lang === "zh" ? "🔒 提示: 一键同步到 Notion 是黄金会员专属特权！请先登录账号解锁。" : "🔒 Notice: Notion 1-Click Sync is a Premium privilege! Please log in to unlock.");
			return;
		}
```

- [ ] **Step 9: 确认前端类型检查通过**

Run: `cd frontend && npx tsc --noEmit`
Expected: 无报错（尤其确认没有遗留对 `licenseKey`/`setLicenseKey`/`verifyLicense` 的引用）

- [ ] **Step 10: Commit**

```bash
git add frontend/src/app/app/page.tsx
git commit -m "feat(frontend): wire account login and cloud sync into web app, drop license key UI"
```

---

### Task 8: 手动端到端验证

**Files:** 无代码改动

- [ ] **Step 1: Firebase Console 手动配置确认**

打开 Firebase Console → `brainvent-9704a` 项目 → Authentication → Sign-in method，确认 "Email/Password" 提供商已启用，并且其下的 "Email link (passwordless sign-in)" 开关已打开。确认 Authentication → Settings → Authorized domains 里包含 `localhost`（本地联调用）。

- [ ] **Step 2: 本地起后端 + Postgres**

```bash
cd backend
docker compose up -d
export DATABASE_URL="postgres://dumpit:dumpit_dev_password@localhost:5432/dumpit?sslmode=disable"
export SESSION_JWT_SECRET="local-dev-secret"
export FIREBASE_PROJECT_ID="brainvent-9704a"
go run main.go
```

- [ ] **Step 3: 本地起前端**

```bash
cd frontend
npm run dev
```

- [ ] **Step 4: 走一遍完整流程**

打开 `http://localhost:3000/app`，展开配置抽屉，在"账号与云同步"里输入一个真实可收信的邮箱、点"发送登录链接"，去邮箱点击收到的链接（会跳回 `http://localhost:3000/app`），确认页面 toast 显示"云同步完成"且"账号与云同步"区域变成已登录状态。录一条新的 dump，确认没有报错。

- [ ] **Step 5: 确认历史记录已经落到后端**

```bash
curl -H "Authorization: Bearer <浏览器 localStorage 里的 dumpit_session_token>" http://localhost:8080/api/history
```

Expected: 返回的 `records` 里包含刚才创建的那条记录。

- [ ] **Step 6: 确认登出/重新登录能拉回历史**

点"登出"，清一下浏览器里的 `dumpit_history`（`localStorage.removeItem("dumpit_history")`），重新走一遍登录链接流程，确认历史记录能从云端拉回来并显示在列表里。

---

## Self-Review Notes

- **Spec coverage：** 架构与身份隔离（Task 1-3 后端 email 支持 + design spec 里明确的不互通限制）、登录数据流（Task 5、Task 7 Step 5）、同步数据流（Task 6、Task 7 Step 5-6）、license key 替换（Task 7 Step 2-4、7-8）、错误处理（`sendLoginLink`/`completeLoginLinkIfPresent`/`pushRecord`/`pullAllHistory`/`fetchSubscription` 内建的 try/catch 与静默失败，Task 5-6）、测试（Task 1-3 的后端单测/集成测试，Task 8 的人工验证）——spec 里的每一节都能对应到具体任务。
- **Placeholder scan：** 未发现 TBD/TODO 或"类似 Task N"这类占位描述；每个 Step 都是可直接执行的具体代码或命令。
- **Type consistency：** 核对了跨任务复用的函数签名——`VerifyFirebaseIDToken`（Task 1 定义 4 返回值，Task 3 按新签名调用一致）、`UpsertUser`（Task 2 定义 `(ctx, uid, phoneNumber, email)`，Task 2 自己的测试和 Task 3 的 handler 调用一致）、`getBackendUrl`/`postJson`/`postJsonAuthed`/`getJsonAuthed`（Task 4 定义，Task 5-6 按同名同签名调用）、`HistoryRecord`（Task 4 定义，Task 6-7 引用一致）、`sendLoginLink`/`completeLoginLinkIfPresent`/`logout`/`hasSessionToken`（Task 5 定义，Task 7 调用一致）、`importLocalHistory`/`pushRecord`/`pullAllHistory`/`fetchSubscription`（Task 6 定义，Task 7 调用一致）。
- **Scope check：** 单一内聚 feature（web 端账号登录 + 云同步基础设施），后端改动被压缩到最小必要范围（只加 email 支持，不碰其他表/接口），符合已批准的 design spec 范围。
