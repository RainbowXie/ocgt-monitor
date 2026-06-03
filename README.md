<div align="center">

# ocgt-monitor

**OpenCode Go 套餐额度 &amp; Token 监控工具**

A lightweight desktop monitor for OpenCode Go plan quota, DeepSeek balance, and token usage.

<p align="center">
  <img src="https://img.shields.io/badge/version-0.4.0-1a56db?style=flat-square" alt="version">
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat-square&logo=go" alt="go">
  <img src="https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square&logo=windows" alt="windows">
  <img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="license">
</p>

</div>

---

## 简介 · Overview

ocgt-monitor 是一款桌面侧边栏工具，实时监控 OpenCode Go 套餐额度、DeepSeek 账户余额和 Token 消耗趋势。三种使用模式满足不同场景。

*Desktop sidebar tool for monitoring OpenCode Go quota, DeepSeek balance, and token consumption trends.*

- **桌面侧边栏** — 半透明毛玻璃面板，屏幕右侧自动隐藏，鼠标唤出
- **网页面板** — 浏览器访问 `http://127.0.0.1:8788`，完整仪表盘
- **命令行** — 终端直接查询，无需 GUI

## 功能 · Features

| 功能 | 说明 |
|------|------|
| 套餐额度 | Rolling / Weekly / Monthly 三条进度条，超阈值变色预警 |
| 账户余额 | DeepSeek 可用余额、赠送、充值明细 |
| 今日消耗 | 输入/输出 Tokens、请求次数，数字滚动动画 |
| 模型分析 | 按模型汇总消耗，支持 1日/7日/30日及自定义日期筛选 |
| 趋势图表 | 7 日堆叠柱状图 + 30 日模型分布环形图 |
| 双主题 | 亮色「灵动卡片」与暗色「深色专业」一键切换 |
| 自动刷新 | 2 秒轮询，数据实时更新 |
| 多账户 | 多 Profile 管理，配置文件独立存储 |

## 快速开始 · Quick Start

```bash
# 1. 配置凭证（首次使用）
ocgt-monitor config init

# 2. 启动桌面侧边栏（推荐）
ocgt-monitor serve --sidebar

# 3. 或在终端直接查询
ocgt-monitor quota
ocgt-monitor balance
```

> **PowerShell 用户：** 命令前加 `.\`，即 `.\ocgt-monitor serve --sidebar`

## 使用模式 · Usage Modes

### 🖥️ 桌面侧边栏

半透明面板固定在屏幕右侧边缘，鼠标移上滑出。支持拖拽调整位置、固定显示、双主题切换。

```bash
ocgt-monitor serve --sidebar
```

*需要 WebView2 Runtime（Windows 11 自带）*

### 🌐 网页面板

浏览器全屏仪表盘，涵盖所有数据视图。

```bash
ocgt-monitor serve
# 访问 http://127.0.0.1:8788
```

自定义端口：`set OCGT_PORT=9090 && ocgt-monitor serve`

### ⌨️ 命令行

```bash
ocgt-monitor quota          # 套餐额度
ocgt-monitor balance        # DeepSeek 余额
ocgt-monitor history        # 7 日消耗历史
ocgt-monitor config         # 查看当前配置
ocgt-monitor config init    # 配置向导
ocgt-monitor config list    # 列出所有账户
ocgt-monitor version        # 版本号
```

## 配置 · Configuration

配置文件位置：`C:\Users\<用户名>\.ocgt-monitor\config.json`

优先级：**环境变量 > 配置文件**

```bash
set OPENCODE_GO_AUTH_COOKIE=session=xxx;.....
set OPENCODE_GO_WORKSPACE_ID=wrk_xxxxxxxxxxxx
set DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
```

## 构建 · Build from Source

```bash
# 需要 Go 1.22+ 和 MSYS2 MinGW64（CGO）
set CGO_ENABLED=1
set PATH=C:\msys64\mingw64\bin;%PATH%
go build -ldflags="-s -w" -o ocgt-monitor.exe .
```

## 项目结构 · Project Structure

```
ocgt-monitor/
  main.go                   CLI 入口
  build.bat                 构建脚本
  internal/
    sidebar/sidebar.go      桌面侧边栏 WebView2
    web/server.go           HTTP 服务（API）
    web/static/sidebar.html 侧边栏 UI（双主题）
    web/static/help.html    使用手册
    quota/                  数据查询器
    config/config.go        配置管理
    state/state.go          全局状态
    formatter/format.go     格式化工具
    storage/reader.go       日志读取与统计
```

## 技术栈 · Tech Stack

**Go 1.22+** · **WebView2** · **OpenCode Go RPC** · **DeepSeek API**

---

<div align="center">
  <sub>Built with Go · WebView2 · Windows</sub>
</div>
