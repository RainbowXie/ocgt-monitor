# DeepSeek 多账户富卡片设计（B）

日期：2026-06-23
状态：方案已确认，待实现

本设计是「多账户监控」功能的第二部分（B）。第一部分见 `2026-06-23-multi-account-cards-design.md`（A：OpenCode Go 多账户卡片）。B 对配置只做追加，不返工 A，两者可独立实现与上线。

## 目标

GUI 面板为**每个** DeepSeek 账户展示一张富卡片：钱包详情（余额、可用 token 估算、本月用量、赠送额度）+ 当前月按天用量堆叠柱状图（输入命中缓存 / 输入未命中缓存 / 输出）。账户数量与 OpenCode Go 账户无关，可多个。某账户 token 失效只影响该卡片。

凭证录入采用弹 webview 登录、自动截获网页 Bearer token 的方式，免去用户手动到浏览器 F12 扒 token。

非目标：CLI 的 DeepSeek 富数据展示（CLI `balance` 命令保持现状）；token 自动续期（过期由「重新登录」一键重抓覆盖）。

## 背景

当前 DeepSeek 走官方 API `https://api.deepseek.com/user/balance` + `Authorization: Bearer sk-xxx`，只能拿到 total/granted/topped 三个余额数。富数据（按天按模型用量、token 估算、当月用量、赠送额度）来自 DeepSeek 平台网页后台 `platform.deepseek.com` 的内部接口，鉴权用网页登录态的 Bearer token（非 sk- key）。

两个网页接口均已实测，**仅需 `authorization: Bearer <token>`、不需要任何 cookie**（cf_clearance / session cookie 都不需要），HTTP 200 正常返回：

1. 钱包/汇总：`GET https://platform.deepseek.com/api/v0/users/get_user_summary`
2. 按天用量：`GET https://platform.deepseek.com/api/v0/usage/amount?month=M&year=Y`

两接口都需带网页客户端标识头：`x-client-platform: web`、`x-client-version: 1.0.0`、`x-app-version: 1.0.0`、`x-client-locale: zh_CN`、`x-client-bundle-id: com.deepseek.chat`、`x-client-timezone-offset: 28800`、`referer: https://platform.deepseek.com/usage`、`accept: */*`，以及一个常规桌面浏览器 `user-agent`。

`get_user_summary` 实测响应（关键字段）：

```json
{"code":0,"msg":"","data":{"biz_code":0,"biz_msg":"","biz_data":{
  "current_token":10000000,
  "monthly_usage":"1061496514",
  "total_usage":0,
  "normal_wallets":[{"currency":"CNY","balance":"65.7173316000000000","token_estimation":"21905777"}],
  "bonus_wallets":[...]
}}}
```

`usage/amount` 实测响应结构：`data.biz_data.{ total[], days[] }`。`days[]` 为当月每天一条；`total` 按模型聚合（如 `deepseek-v4-pro`、`deepseek-v4-flash`、`deepseek-chat & deepseek-reasoner`）。每个 `usage[]` 的 `type` 取值：`PROMPT_TOKEN`、`PROMPT_CACHE_HIT_TOKEN`、`PROMPT_CACHE_MISS_TOKEN`、`RESPONSE_TOKEN`、`REQUEST`。其中 `PROMPT_TOKEN = PROMPT_CACHE_HIT_TOKEN + PROMPT_CACHE_MISS_TOKEN`，单日总量 = 命中缓存 + 未命中缓存 + 输出（用户提供的样例已对账：214,893,568 + 3,132,080 + 288,637 = 218,314,285）。

## 配置模型

`Config` 顶层新增独立列表，与 `Profiles`（OpenCode 账户）解耦：

```go
type DeepSeekAccount struct {
    Name  string `json:"name"`
    Token string `json:"token"` // 网页 Bearer token
}

type Config struct {
    ActiveProfile    string             `json:"active_profile"`
    Profiles         map[string]Profile `json:"profiles"`
    DeepSeekAccounts []DeepSeekAccount  `json:"deepseek_accounts,omitempty"`
}
```

旧的 per-profile `deepseek_api_key`（官方 sk- key）与网页 token 鉴权不兼容，B 不复用，保留忽略（A 设计已说明）。`config.json` 仍走 `Load`/`Save`，权限 0600 不变。

新增配置操作方法（与现有 `AddProfile`/`DeleteProfile` 风格一致）：按 `Name` 新增或覆盖 `DeepSeekAccount`、按 `Name` 删除。

## 凭证录入：webview 登录自动抓 token

GUI 用的是 `github.com/webview/webview_go`，支持 `Navigate` / `Init` / `Eval` / `Bind`。利用这点做一次性登录抓取窗口。

### 流程

新增子命令 `ocgt-monitor login-deepseek [账户名]`（独立进程、独立 webview 窗口，避免与侧边栏 webview 同时存在——webview_go 一个进程只宜一个窗口）：

1. `Bind("__ocgtCaptureToken", fn)` 暴露 Go 回调；`Init(js)` 注入拦截脚本；`Navigate("https://platform.deepseek.com/sign_in")`。
2. 注入脚本在页面脚本之前运行，monkey-patch `XMLHttpRequest.prototype.setRequestHeader` 与 `window.fetch`，检测请求头里的 `authorization: Bearer <token>`。用户登录后页面会自动发 `get_user_summary` 等带 Bearer 的请求，脚本截获该 token 的首次出现，调用 `__ocgtCaptureToken(token)`。
3. Go 回调拿到 token 后，用它发一次 `get_user_summary` 校验有效（HTTP 200 且 `code==0`），成功则写入 `DeepSeekAccounts`（账户名未给时提示输入或用默认名），随后 `Terminate()` 关窗。
4. 校验失败则在窗口内提示并保持打开，等待重试。

采用「截获 Authorization 头」而非「读 localStorage 指定 key」，是因为 token 存储 key 名未知且可能变动，而 Authorization 头是页面发请求的稳定事实来源，更可靠。

### 约束

- webview_go 无网络请求拦截 API，截获在页面 JS 层完成，依赖 token 以 Bearer 形式出现在前端可见的请求头中（已由实测确认页面就是这样发请求的）。
- 网页 Bearer token 会过期。过期后对应卡片报鉴权错，用户点卡片上的「重新登录」即重跑本流程刷新 token。

### GUI 触发

- 「添加 DeepSeek 账户」与卡片内「重新登录」按钮，经服务端新增轻量端点 `POST /api/deepseek/login`（参数 `name`）触发：服务端以子进程方式运行 `login-deepseek <name>`，子进程开自己的 webview 完成抓取与落盘，结束后面板重新拉取 `/api/deepseek`。
- 首次配置也可直接命令行 `ocgt-monitor login-deepseek <name>`。

## 后端

### 查询器（internal/quota/deepseek_web.go，新增）

```go
type DeepSeekWebQuerier struct{ Token string }
```

- `FetchSummary() (*DeepSeekSummary, error)`：调 `get_user_summary`，解析 `biz_data`。`normal_wallets` 同币种求和得余额；`token_estimation`、`monthly_usage`、`current_token` 字符串转数值。`本月花费`(¥) 字段在实测截断处之后，实现时从完整响应确认对应 key，缺失则该项省略、前端不展示。
- `FetchUsage(year, month int) ([]DeepSeekDayUsage, error)`：调 `usage/amount`，对 `days[]` 每天跨模型求和：`CacheHit=Σ PROMPT_CACHE_HIT_TOKEN`、`CacheMiss=Σ PROMPT_CACHE_MISS_TOKEN`、`Output=Σ RESPONSE_TOKEN`、`Total=CacheHit+CacheMiss+Output`。
- 统一设置上面列出的 `x-client-*` 等请求头；非 200 或 `code!=0` 返回错误（鉴权失败错误文案需可被前端识别为「token 失效」）；每次请求独立超时（沿用现有 15s 量级）。

### 数据结构（internal/quota/types.go，新增）

```go
type DeepSeekSummary struct {
    Currency        string  `json:"currency"`
    Balance         float64 `json:"balance"`
    TokenEstimation int64   `json:"token_estimation"`
    MonthlyUsage    int64   `json:"monthly_usage"`
    CurrentToken    int64   `json:"current_token"`
}

type DeepSeekDayUsage struct {
    Date     string `json:"date"`
    CacheHit int64  `json:"cache_hit"`
    CacheMiss int64 `json:"cache_miss"`
    Output   int64  `json:"output"`
    Total    int64  `json:"total"`
}
```

### 端点（internal/web/server.go）

新增 `GET /api/deepseek`：并发查询配置里所有 `DeepSeekAccounts`，每账户独立 `DeepSeekWebQuerier`、独立超时、独立成败，查当前月。返回按 `name` 升序：

```json
{
  "success": true,
  "data": [
    { "name": "账号A", "success": true,  "summary": { /* DeepSeekSummary */ }, "days": [ /* DeepSeekDayUsage */ ] },
    { "name": "账号B", "success": false, "error": "鉴权失败：token 可能已过期" }
  ]
}
```

`NewServer` 需能拿到 `DeepSeekAccounts`（由 `main.go` 从 `cfg` 构建传入，`web` 包定义自身的 account 结构，避免依赖 `config` 包，与 A 的处理一致）。

新增 `POST /api/deepseek/login`（见上「GUI 触发」）。

保持不动：`/api/balance`（官方 sk 单卡，供 CLI 与无网页 token 时的回退）、`/api/quota`、`/api/history`、`/api/models` 等。GUI 面板上原「账户余额」单卡区由新的 DeepSeek 卡片区取代；CLI `balance` 命令不动。

## 前端（internal/web/static/sidebar.html）

- DeepSeek 区域改为**卡片容器 + 模板**，按 `/api/deepseek` 动态渲染 N 张卡片，卡片内 DOM 用克隆模板/相对查询，避免全局写死 ID 冲突（与 A 同样的多卡片注意点）。
- 每张卡片：
  - 标题：账户名 + DeepSeek
  - 钱包行：`余额 ¥{balance} · 可用≈{token_estimation} tokens` / `本月 用量{monthly_usage} · 赠送{current_token}`（`本月花费` 字段确认存在后追加）
  - 当前月按天堆叠柱状图：x 轴为日期（当月各天），每根柱 3 段堆叠 = 输入命中缓存 / 输入未命中缓存 / 输出，复用现有日趋势图的渲染风格与配色。
  - 末尾「重新登录」按钮（触发 `POST /api/deepseek/login`）。
- 顶部「添加 DeepSeek 账户」入口（同样触发登录抓取）。
- 逐卡状态：加载中占位；该账户 `success:false` 时卡片内显示错误文案，鉴权类错误额外提示「token 可能已过期，请重新登录」，不影响其它卡片与面板其余部分。
- 刷新：周期刷新加入重新拉取 `/api/deepseek` 并重渲染卡片；其余 fetch 不变。复用已上线的可缩放/滚动窗口。

## 错误处理

- 单账户查询失败（token 过期、网络等）→ 该卡片报错，`/api/deepseek` 整体仍 `success:true`。
- 登录抓取流程：用户关窗未完成 → 不写配置、不报致命错；token 校验失败 → 窗口内提示重试。
- 整个请求失败（服务未起等）→ 沿用现有顶部状态点错误态。

## 验证

- `CGO_ENABLED=0 go build -tags nogui .` 通过、`go vet -tags nogui ./...` 通过（后端逻辑与编译本机可验证）。
- 后端：配置两个 `deepseek_accounts`（一个有效 token、一个失效 token），本机起 `serve`，`curl /api/deepseek` 应返回两条，分别 `success:true`（含 summary 与 days）/`false`（鉴权错），按 name 排序；逐字段核对 summary 数值与按天 total = 命中+未命中+输出。
- 抓取流程：跑 `login-deepseek 测试账户`，弹窗登录后确认 token 被截获、校验通过、写入 `config.json`、窗口自动关闭；用过期 token 场景确认卡片报鉴权错且「重新登录」可重抓。
- 前端：面板渲染多张 DeepSeek 卡片，钱包行数值正确，堆叠柱状图与官网当月用量趋势一致；失效账户卡片单独报错。
- GUI 完整窗口（含抓取窗口）由 CI 三平台编译验证。

## 影响范围

- 改动：`internal/config/config.go`（加 `DeepSeekAccount` + `DeepSeekAccounts` + 增删方法）、`internal/quota/deepseek_web.go`（新查询器）、`internal/quota/types.go`（新结构）、`internal/web/server.go`（`/api/deepseek` + `/api/deepseek/login` + `NewServer` 接收 DeepSeek 账户）、`internal/web/static/sidebar.html`（DeepSeek 卡片区 + 堆叠柱状图 + 登录按钮）、`main.go`（`login-deepseek` 子命令 + webview 抓取窗口 + 接线）。
- 不改：A 涉及的 OpenCode 多卡逻辑、`/api/balance`、CLI `balance`、token 全局图表、其余端点。

## 安全提醒

网页 Bearer token 是真实有效凭证，会写进本地 `config.json`（0600）。token 会过期，过期后经「重新登录」刷新。配置文件应避免随仓库或截图外泄。
