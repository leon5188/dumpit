# 账号体系 + 云同步 设计文档

日期: 2026-08-03
范围: BrainVent (dumpit) Flutter 手机端 + Go 后端。Web 前端（Next.js）不在本次范围内。

## 背景与目标

当前状态：
- 历史记录（`_historyList`）完全存在手机本地 `SharedPreferences`，换设备/重装即丢失。
- "文风克隆"依赖用户手动填写的一段静态文字（`user_tone_sample`），存本地，从不自动更新，绝大多数用户不会去填，形同虚设。
- 订阅状态（IAP 收据验证 + License 激活码）都是设备级的，不跟账号绑定，换设备需要重新验证。
- 后端目前没有任何数据库、没有用户认证体系。

目标：
1. 引入账号体系（手机号登录，面向海外/全球市场，用 Firebase Phone Auth）。
2. 历史记录云端同步，换设备/重装不丢数据。
3. 订阅状态迁移到账号维度，换设备后无需重新验证收据。
4. 顺带解决个性化摘要问题：后端基于账号历史自动生成动态文风样例，替代手动填写。

不做的事（明确排除，避免范围蔓延）：
- Web 前端（Next.js）暂不接入登录/同步，仍保持现状。
- 不做订阅历史流水/多端订阅分析，`subscriptions` 表只存当前状态一行。
- 不做自动化端到端测试框架，端到端验证走手动真机流程。
- 不支持账号间数据迁移/合并、注销账号等边缘管理功能。

## 架构与数据流

```
手机端 (Flutter)
  └─ FlutterFire SDK 发送/校验手机验证码
  └─ 拿到 Firebase ID Token
  └─ POST /api/auth/verify (带 ID Token)
       └─ 后端验证 Firebase ID Token 签名 (Google 公钥校验 JWT，不引入完整 Firebase Admin SDK)
       └─ users 表里没有该 uid 则自动建号 (首次登录 = 自动注册)
       └─ 返回后端自签发的 session token (JWT, 7 天有效期)
  └─ 之后所有请求带 `Authorization: Bearer <session_token>`
       └─ AuthMiddleware 解析校验，把 uid 存入 echo context
```

**本地优先原则**：本地 `SharedPreferences` 数据永远是可用的兜底。同步失败只标记"待同步"，不阻塞用户当前操作，下次联网自动重试。

**首次登录迁移**：用户首次登录成功后，客户端把本地全部历史记录一次性 POST 到 `/api/history/import`，成功导入的记录标记本地"已同步"，之后新记录本地写入的同时异步同步到云端（双写）。

**订阅迁移**：`/api/iap/verify`、`/api/license/verify` 验证成功后，除了原有逻辑外，额外 upsert 一行到 `subscriptions` 表（按 `uid` 唯一），换设备登录同一账号后，`GET` 订阅状态直接查表返回，不需要重新验证收据/激活码。

## 数据模型 (Postgres，Render 托管)

选 Postgres 而非 SQLite：Render 容器重启不保证磁盘持久化，SQLite 在该平台上有丢数据风险；Postgres 是唯一可靠选项。不引入 ORM（如 GORM），三张表用 `database/sql` + `pgx` 原生 SQL 足够，避免为小 schema 引入框架开销。

### users
| 字段 | 类型 | 说明 |
|---|---|---|
| uid | text PK | 直接用 Firebase UID 做主键 |
| phone_number | text unique | Firebase 返回的手机号 |
| created_at | timestamptz | |

### subscriptions
| 字段 | 类型 | 说明 |
|---|---|---|
| uid | text PK, FK→users | 每个 uid 一行，只存当前状态 |
| product_id | text | 对应 IAP 商品 ID |
| expires_at | timestamptz | 订阅到期时间 |
| source | text | `iap` 或 `license_code` |
| updated_at | timestamptz | |

### history_records
| 字段 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | |
| uid | text FK→users | |
| summary | jsonb | 直接对应现有 `ProcessedDump` 结构（summary/action_items/key_insights/calendar_events 整体存 jsonb，不拆子表——读写都走同一个 Go struct，没有跨语言查询 jsonb 内部字段的需求，拆表是过度设计） |
| raw_text | text | Whisper 转录原文，供个性化摘要拼 prompt 使用 |
| created_at | timestamptz | |
| archived | boolean | 对应现有本地归档逻辑 |

## API 设计

- `POST /api/auth/verify` — body 带 Firebase ID Token；验证签名+过期；uid 不存在则自动建号；返回后端自签发 session token (JWT, 7 天有效期)。
- `AuthMiddleware` — 解析 `Authorization: Bearer <session_token>`，校验签名/过期，uid 存入 echo context，后续 handler 直接取用，不重复验证。
- `POST /api/history/import` — 首次登录批量导入本地历史；逐条写入，单条失败不影响整体，响应中标出失败的记录（避免一条脏数据毁掉整批导入）。
- `POST /api/history` — 新建一条记录（`RestructureDump` 返回结果后客户端调用同步到云端）。
- `GET /api/history?since=<timestamp>` — 增量拉取，用于换设备/重装后同步。
- `PATCH /api/history/:id` — 归档/删除状态同步。
- `POST /api/iap/verify`、`POST /api/license/verify` — 原逻辑不变，验证成功后额外 upsert `subscriptions` 表（按当前登录 uid）。
- `GET /api/subscription` — 查询当前账号订阅状态，换设备登录后直接调用，无需重新验证收据。

**个性化摘要**：`RestructureDump` 调用前，后端查该 uid 最近 5 条 `history_records.summary`，拼接成动态 tone sample 传入 prompt。前端手动填写的"文风样例"输入框保留作为可选覆盖项，默认走自动生成。

## 错误处理

- Session token 过期/无效 → 401；客户端收到 401 后先用 Firebase 静默刷新 token 重试一次，仍失败才要求用户重新登录。
- 导入接口单条记录写入失败（如 jsonb 格式异常）→ 跳过该条，不整体回滚，响应中列出失败记录 id。
- 网络不可用 → 本地优先策略，操作永远先在本地完成，同步状态标记"待同步"，联网后自动重试，不阻塞当前操作。

## 测试思路

- `AuthMiddleware` token 校验：单元测试覆盖有效 token 通过、过期 token 拒绝、篡改签名拒绝（安全边界，必须测）。
- 个性化摘要拼接函数（取最近 5 条 summary）：单独抽函数写单元测试，覆盖 0 条历史、少于 5 条历史的边界情况。
- 订阅 upsert 逻辑：单元测试验证同一 uid 重复验证同一收据不会重复插入，而是更新 `expires_at`。
- 迁移导入接口：上线前手动跑一次，本地造 20 条假历史记录（含 1 条故意格式错误的），验证 19 条成功导入、1 条被跳过且在响应中标出。
- 换设备后能否拉取历史：走 `run`/`verify` 真机验证，不建自动化端到端测试框架，量级未到需要 E2E 框架的程度。
