<div align="center">

# foundry-quota-sentinel

**Multi-provider LLM quota &amp; usage monitor**

*One desktop sidebar to watch OpenCode Go quota and DeepSeek token usage — multi-account, browser login.*

<p align="center">
  <img src="https://img.shields.io/badge/version-0.7.1-4466FF?style=flat-square" alt="version">
  <img src="https://img.shields.io/badge/Go-1.26+-00ADD8?style=flat-square&logo=go" alt="go">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-0078D4?style=flat-square" alt="platform">
  <img src="https://img.shields.io/badge/build-CGO-FF2D78?style=flat-square" alt="cgo">
  <img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="license">
</p>

<br>

<img src="screenshots/sidebar.png" width="340" alt="foundry-quota-sentinel sidebar screenshot">

<br><br>

**English** &nbsp;|&nbsp; [**中文**](README.md)

</div>

<br>

---

## Features

<table>
<tr>
  <td width="50%"><strong>OpenCode Go · Multi-account</strong><br><span style="color:#5A5A7A;font-size:13px">All accounts at once — Rolling / Weekly / Monthly quota bars with 80%/95% color warnings; a failing account only affects its own card.</span></td>
  <td width="50%"><strong>DeepSeek · Multi-account</strong><br><span style="color:#5A5A7A;font-size:13px">Balance + this month's per-model daily token usage (echarts stacked bars: cache hit / miss / output).</span></td>
</tr>
<tr>
  <td><strong>Browser login</strong><br><span style="color:#5A5A7A;font-size:13px">A pop-up login captures credentials automatically — OpenCode web Cookie, DeepSeek web Token — no manual F12 copy-paste.</span></td>
  <td><strong>Dual theme</strong><br><span style="color:#5A5A7A;font-size:13px">Light "glassy cards" and dark "pro" themes, one-click switch.</span></td>
</tr>
<tr>
  <td colspan="2"><strong>Auto refresh</strong><br><span style="color:#5A5A7A;font-size:13px">Account quota polled every 2s; DeepSeek usage on a timer.</span></td>
</tr>
</table>

## Quick Start

1. **Download** the binary for your platform from Releases.
2. **Add an account** — click the "Add account" card at the bottom of the panel → choose OpenCode or DeepSeek → log in via the pop-up, credentials are saved automatically. Or from the CLI: `foundry-quota-sentinel login-deepseek <name>` / `login-opencode <name>`.
3. **Run** — double-click the binary; the desktop sidebar starts, no terminal needed.

> **PowerShell:** prefix commands with `.\`, e.g. `.\foundry-quota-sentinel login-deepseek myacct`

## Platform Support

| Platform | GUI form | OpenCode browser login | DeepSeek browser login | CLI / web panel |
|---|---|---|---|---|
| Windows | Edge-docked auto-hiding sidebar | via `config add` (manual) | ✅ | ✅ |
| macOS | Standalone window | via `config add` (manual) | ✅ | ✅ |
| Linux | Standalone window | ✅ | ✅ | ✅ |

> OpenCode's login credential is an httpOnly Cookie; auto-capture relies on the system WebView's cookie store and is currently implemented on Linux (WebKitGTK). Other platforms use `config add` to enter Cookie / Workspace ID manually. DeepSeek's credential is a web Token and can be captured by the pop-up on all three platforms. Edge-docked auto-hide is a Windows-native capability.

## Build from Source

Build dependencies (CGO):
- **Windows**: MinGW64 (gcc)
- **macOS**: Xcode Command Line Tools
- **Linux**: `libgtk-3-dev libwebkit2gtk-4.0-dev`

```bash
# macOS / Linux native GUI
go build -ldflags="-s -w" -o foundry-quota-sentinel .

# Windows GUI (see build.bat)
build.bat

# Build the Linux GUI binary via Docker (webkit deps inside the container)
./scripts/build-linux.sh

# No native GUI window, no CGO (still has CLI + serve web panel; for servers/debugging)
CGO_ENABLED=0 go build -tags nogui -o foundry-quota-sentinel .
```

Release binaries are built natively on three platforms by GitHub Actions and published to Releases on `v*` tag push.

## Usage

**Desktop sidebar** — a translucent panel shows a single column of account cards: all OpenCode Go accounts on top, all DeepSeek accounts below, and an "Add account" card at the bottom. Supports drag-to-position, pin, theme switch.

```bash
foundry-quota-sentinel serve --sidebar   # or just double-click the binary
```

**Web panel** — open `http://127.0.0.1:8788` for the same panel in a browser.

```bash
foundry-quota-sentinel serve
```

**CLI** — quick queries & credential management.

| Command | Purpose |
|------|------|
| `quota` | OpenCode Go subscription quota (active account) |
| `balance` | DeepSeek balance (official API key) |
| `history` | Local 7-day token usage history |
| `login-deepseek <name>` | Pop-up login, save DeepSeek web Token |
| `login-opencode <name>` | Pop-up login, save OpenCode Cookie (Linux) |
| `config init` / `config add <name>` | Interactive setup / add account |
| `config list` / `config use <name>` | List / switch accounts |

## Configuration

Config lives in `~/.foundry-quota-sentinel/config.json` (Windows: `%USERPROFILE%\.foundry-quota-sentinel\config.json`), per user. OpenCode accounts under `profiles`, DeepSeek accounts under `deepseek_accounts`. (A legacy `~/.ocgt-monitor` directory is migrated automatically on first run.)

Environment variables override the config file (for the CLI's active-account queries only):

```bash
export OPENCODE_GO_AUTH_COOKIE='session=xxx; ...'
export OPENCODE_GO_WORKSPACE_ID='wrk_xxxxxxxxxxxx'
export DEEPSEEK_API_KEY='sk-xxxxxxxxxxxxxxxx'
```

## Tech Stack

**Go 1.26+** · system WebView (WebKitGTK / WKWebView / WebView2) · **echarts** · OpenCode Go RPC · DeepSeek web API

---

<div align="center">
  <sub>Built with Go &middot; system WebView &middot; echarts</sub>
</div>
