#!/usr/bin/env bash
# 把一个已编好的二进制打成 .deb（纯打包，不负责编译）。本地和 CI 共用。
# 用法: scripts/pack-deb.sh <binary> <version> <depends> <webkit> <out.deb>
set -euo pipefail
BIN="$1"; VERSION="$2"; DEPENDS="$3"; WEBKIT="$4"; OUT="$5"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/DEBIAN" "$WORK/usr/bin" "$WORK/usr/share/applications"
install -m0755 "$BIN" "$WORK/usr/bin/foundry-quota-sentinel"

cat > "$WORK/DEBIAN/control" <<CTRL
Package: foundry-quota-sentinel
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: ${DEPENDS}
Maintainer: RainbowXie <noreply@users.noreply.github.com>
Homepage: https://github.com/RainbowXie/foundry-quota-sentinel
Description: 多服务商 LLM 额度与用量监控 (webkit ${WEBKIT})
 桌面侧边栏统一监视 OpenCode Go 额度与 DeepSeek token 用量，多账户、浏览器登录。
 此包针对 webkit2gtk-${WEBKIT}；请按发行版选择对应的 webkit 版本。
CTRL

cat > "$WORK/usr/share/applications/foundry-quota-sentinel.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Foundry Quota Sentinel
Comment=多服务商 LLM 额度与用量监控
Exec=foundry-quota-sentinel
Terminal=false
Categories=Utility;Network;Monitor;
DESK

dpkg-deb --build --root-owner-group "$WORK" "$OUT" >/dev/null
echo ">>> $OUT"
dpkg-deb --info "$OUT" | grep -E "Package|Version|Architecture|Depends"
