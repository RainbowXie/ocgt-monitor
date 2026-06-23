# OpenCode Go 多账户卡片设计（A）

日期：2026-06-23
状态：已批准，待实现

本设计是「多账户监控」功能的第一部分（A）。第二部分（B：DeepSeek 多账户富卡片，含按天用量图与钱包详情）单独立 spec，B 对配置只做追加、不返工本设计。

## 目标

GUI 面板同时展示**所有** OpenCode Go 订阅账户，每个账户一张完整卡片（账号名 + Rolling/Weekly/Monthly 额度进度条 + 重置时间）。某账户查询失败只影响该卡片，其余照常。

非目标（属 B 或后续）：DeepSeek 多账户富卡片、CLI 多账户管理、token 全局图表改造。

## 背景

`internal/config/config.go` 的 `Profiles map[string]Profile`（每个含 `Cookie`、`WorkspaceID`）本身即多账户存储，但当前运行时只用 active 一个：`main.go` 的 `makeQuotaQuerier()` 取 `GetActiveProfile()`，`web.NewServer` 只持有单个 querier，面板 `/api/quota` 只返回该账户。

额度按账户区分（cookie+workspace 决定）。token 历史/模型图表来自本机 `ocgt` 日志，是全局单一数据源，与账户无关，保持现状。

quota API 响应不含账号标识，卡片标题用 profile 名（map key）。

## 配置模型

A 不改配置 schema。`Profiles` 即 OpenCode Go 账户来源，账户名 = map key。

DeepSeek 多账户在 B 阶段以独立的 `deepseek_accounts` 列表新增（与 OpenCode 账户数量无关），对本设计是纯追加。旧的 per-profile `deepseek_api_key`（官方 sk- key）与 B 的网页 token 鉴权不兼容，B 不复用，保留忽略。

## 后端（internal/web/server.go）

新增 `GET /api/accounts`：

- 输入账户列表来自配置的所有 profile（见下「账户来源」）。
- 并发查询每个账户的额度（每账户独立 `OpenCodeGoQuerier{Cookie, WorkspaceID}`、独立 15s 超时、独立成败）。
- 返回：

```json
{
  "success": true,
  "data": [
    { "name": "账号A", "success": true,  "quota": { /* QuotaData */ } },
    { "name": "账号B", "success": false, "error": "API returned 401: ..." }
  ]
}
```

- `data` 按 `name` 升序排序，保证卡片顺序稳定。

账户来源与 `NewServer`：

- `NewServer` 改为接收账户列表（`[]Account{Name, Cookie, WorkspaceID}`，由 `main.go` 从 `cfg.Profiles` 构建），不再只持有单个 querier。`web` 包定义该 `Account` 结构，避免 `web` 依赖 `config` 包。
- `main.go` 的 `startSidebar()` 与 `cmdServe()` 构建账户列表传入：遍历 `cfg.Profiles`，取 `Cookie`/`WorkspaceID` 非空者。
- 兼容回退：若账户列表为空但环境变量 `OPENCODE_GO_AUTH_COOKIE`/`OPENCODE_GO_WORKSPACE_ID` 均有值，合成一个名为「默认」的账户。

保持不动：`/api/quota`（单账户，供 CLI/外部）、`/api/balance`（DeepSeek 单卡，env sk）、`/api/history`、`/api/models`、`/api/pin`、`/api/position` 等。

## 前端（internal/web/static/sidebar.html）

- 将当前写死 ID 的单账户额度区，改为**卡片容器 + 卡片模板**，按 `/api/accounts` 返回动态渲染：返回 N 个账户就渲染 N 张完整卡片。
- 每张卡片：账号名标题 + Rolling/Weekly/Monthly 三条进度条（复用现有 `.qr/.qbw/.qf/.qp/.qtm` 样式与 `bg()` 阈值配色）+ 各自重置时间。
- 卡片内 DOM 用相对查询或克隆模板，避免现有写死的全局 ID（`qfR`/`qpW` 等）在多卡片下冲突。
- 逐卡状态：加载中显示占位；该账户 `success:false` 时卡片内显示错误文案，不影响其它卡片与面板其余部分。
- DeepSeek 单卡、今日 token、模型明细、图表区保持现状（全局单份）。
- 刷新：现有周期刷新改为重新拉取 `/api/accounts` 并重渲染卡片；其余 fetch 不变。
- 复用已上线的可缩放窗口（卡片多时纵向滚动）。

## 错误处理

- 单账户查询失败（cookie 失效、网络等）→ 该卡片显示错误，`/api/accounts` 整体仍 `success:true`。
- 整个请求失败（服务未起等）→ 顶部状态点转错误态（沿用现有 `sd/ht` 错误样式）。

## 验证

- `CGO_ENABLED=0 go build -tags nogui .` 通过；`go vet -tags nogui ./...` 通过（本机可验证编译与后端逻辑）。
- 后端：本机起 `serve`，配置两个 profile（一个有效、一个无效 cookie），`curl /api/accounts` 应返回两条，分别 `success:true`/`false`，按 name 排序。
- 前端：浏览器开面板，确认渲染多张卡片、无效账户卡片单独报错、有效卡片正常显示额度。
- GUI 完整窗口由 CI 三平台编译验证。

## 影响范围

- 改动：`internal/web/server.go`（新增 `/api/accounts` + `Account` 结构 + `NewServer` 签名）、`internal/web/static/sidebar.html`（卡片化）、`main.go`（构建账户列表传入 `NewServer` 的两处调用）。
- 不改：`internal/config`、CLI、DeepSeek、token 图表、其余端点。
