//go:build !(linux && !nogui)

package sidebar

import "fmt"

// RunOpenCodeLogin 仅在 Linux(WebKitGTK) 上实现（需读 cookie store 的 httpOnly cookie）。
// 其它平台与无 GUI 构建回退到手动配置。
func RunOpenCodeLogin(validate func(cookie, wsid string) bool) (string, string, error) {
	_ = validate
	return "", "", fmt.Errorf("OpenCode Go 弹窗登录目前仅支持 Linux(WebKitGTK)；其它平台请用 `foundry-quota-sentinel config add <名称>` 手动配置")
}

// RunOpenCodePage 注入 httpOnly cookie 依赖 WebKitGTK cookie store，仅 Linux 实现；
// 其它平台返回错误，调用方会回退到系统浏览器打开。
func RunOpenCodePage(pageURL, cookie string) error {
	_, _ = pageURL, cookie
	return fmt.Errorf("内置窗口注入 cookie 目前仅支持 Linux(WebKitGTK)")
}
