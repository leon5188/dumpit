# Web 端账号体系 + 云同步 Design Spec

**Goal:** 给 web 端（`frontend/`，BrainVent 的 Next.js 单页应用）加上账号登录能力，让历史记录和订阅状态可以云端持久化，并用登录状态替代现有的 license key 手动解锁流程。

**Relationship to mobile:** mobile 端（`dumpit_mobile/`）已经实现了同类账号体系（见 `docs/superpowers/plans/2026-08-03-account-cloud-sync.md`），用的是 Firebase Phone Auth。本设计给 web 端接入**同一个后端**，但登录方式选择 Firebase Email Link（邮箱链接登录），理由：
- Phone Auth 在浏览器端强制要求 reCAPTCHA，网页体验较重
- web 和 mobile 的用户身份**不互通**——这是本设计明确接受的限制。同一个人在两端登录会产生两个独立的 Firebase UID，各自绑定各自的历史记录与订阅状态。若未来需要跨端打通，需要单独做账号绑定/合并，不在本设计范围内。

## 架构

后端 `POST /api/auth/verify`、`RequireAuth` 中间件、`/api/history`、`/api/subscription` 均已是通用（仅依赖 Firebase ID Token 的签名校验，不依赖登录方式），本设计**复用全部现有后端接口**，只做两处小改动：

1. `services/firebase_auth.go`：`FirebaseClaims` 增加 `Email string \`json:"email"\`` 字段；`VerifyFirebaseIDToken` 返回值从 `(uid, phoneNumber, err)` 改为 `(uid, phoneNumber, email, err)`
2. `db/db.go` schema：`users` 表增加 `email TEXT UNIQUE`（nullable，与 `phone_number` 一样允许多行 NULL）
3. `db/users.go`：`UpsertUser` 签名从 `(ctx, uid, phoneNumber)` 改为 `(ctx, uid, phoneNumber, email)`，插入/更新时把二者都写入（对方为空字符串时存空/NULL）
4. `handlers/auth.go`：`VerifyAuthHandler` 透传 email 给 `UpsertUser`

前端新增三个小模块（`frontend/src/app/app/lib/`），走纯函数风格，不用 class 或 React Context——与现有 `page.tsx` 单页单消费者的体量匹配，是 mobile 端 `AuthService`/`SyncService` 的对应物但更轻量：

- `firebase.ts` — Firebase Web SDK 初始化（需要在 Firebase Console 给现有项目新增一个 Web App，拿到 web config；并在 Authentication 设置里启用 Email Link 登录方式、把部署域名加入 Authorized domains）
- `auth.ts` — `sendLoginLink(email)` / `completeLoginLinkIfPresent()` / `logout()` / session token 的存取（`localStorage` key: `dumpit_session_token`，与 mobile 的 SharedPreferences 存法平行但各自独立）
- `sync.ts` — `pushRecord(record)` / `pullHistory()` / `fetchSubscription()`，对接后端 `/api/history`、`/api/subscription`

`page.tsx` 改动：
- 新增登录态 UI（邮箱输入 → 发送链接 → 状态提示），去掉 `licenseKey`/`verifyLicense` 相关的 UI 和 state
- init `useEffect` 里检测邮件链接回跳并完成登录
- 登录成功时触发 `pullHistory()` 合并本地历史、`fetchSubscription()` 更新 `isPremium`
- 新建历史记录后 `unawaited` 调用 `pushRecord()`（失败静默，不阻塞、不重试）
- 未登录时的付费功能提示从"请输入激活码"改为"请登录"

## 数据流

**登录（Email Link 两步）**
1. 用户在 UI 输入邮箱 → `auth.ts: sendLoginLink(email)` 调 Firebase `sendSignInLinkToEmail`；邮箱同时写入 `localStorage`（同设备点击回跳时免重复输入）
2. 用户点邮件里的链接回到 `/app` → init `useEffect` 用 `isSignInWithEmailLink(auth, window.location.href)` 检测 → 命中则 `completeLoginLinkIfPresent()`：`signInWithEmailLink` 拿到 Firebase User → 取其 ID Token → `POST /api/auth/verify` → 拿到 `session_token` 存 `localStorage`（key: `dumpit_session_token`）→ 清掉回跳用的邮箱缓存，并用 `history.replaceState` 清理 URL 上的验证参数

**登录后同步**
- 登录成功那一刻：`pullHistory()` 拉 `GET /api/history`（带 `Authorization: Bearer <session_token>`），与本地 `dumpit_history` 按 `id` 去重合并（服务端记录补充本地没有的），写回 `localStorage` 并 `setHistoryList`
- 之后每次新建历史记录（`_uploadAndProcessAudio` 写入 `dumpit_history` 之后）：`unawaited` 调用 `pushRecord(record)` —— 失败不阻塞、不重试、不提示，本地永远是可用兜底
- 订阅状态：登录后 `fetchSubscription()` 决定 `isPremium`，不再读 `dumpit_is_premium`/`dumpit_license_key`

**未登录 / 登出**
- 未登录：不显示 license key 输入框；付费功能点位提示改为"登录以解锁"，点击跳转登录入口
- 登出：清 `dumpit_session_token`，`isPremium` 回退为 `false`；`dumpit_history` 本地数据保留不清空

## 错误处理

- `sendLoginLink` 失败（邮箱格式错、网络错）→ toast 提示，不影响其他功能
- 邮件链接回跳但 `completeLoginLinkIfPresent` 失败（链接过期/已使用）→ toast 提示重新发送，不清本地历史
- `POST /api/auth/verify` 返回非 2xx 或网络错 → 视为登录失败，不写 `session_token`
- `pullHistory`/`pushRecord`/`fetchSubscription` 失败 → 静默失败（可 console.warn），本地数据不受影响 —— 沿用 mobile 分支已定的 local-first 原则
- email 唯一约束：`ON CONFLICT (uid)` 意味着同一 uid 换设备重登不会冲突；两个不同 uid 声称同一 email 理论上 Firebase 不会发生，不做额外处理

## 测试

- 沿用 mobile 分支的约定：不写自动化端到端测试，人工验证为主
- 后端 `email` 解析 + `UpsertUser` 改动补一个单元测试，风格对齐现有 `db/db_test.go`
- 人工验证步骤：本地跑 `frontend`（`npm run dev`）+ `backend`，输入邮箱登录 → 点击邮件链接完成登录 → 创建一条 dump → 确认后端 `GET /api/history` 能查到该记录 → 登出重新登录 → 确认历史记录被拉回本地

## Out of Scope

- web 与 mobile 账号打通/合并
- 移除 mobile 端或后端的 license key 机制（`backend/handlers/license.go` 保持不变，mobile 继续使用）
- 除 Email Link 外的其他 web 登录方式（Google 登录等）
