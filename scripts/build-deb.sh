#!/usr/bin/env bash
# 打两个 .deb：webkit 4.0（老发行版）+ webkit 4.1（新发行版）。
# 各自 Depends 对应的 webkit/gtk，apt 安装时自动拉依赖，免去手动装 webview。
#
# 用法：scripts/build-deb.sh            # 编两套二进制并打两个 deb 到 build/
#       SKIP_BUILD=1 scripts/build-deb.sh   # 复用 build/ 里已编好的二进制，只打包
#
# 需要：docker（编二进制）、dpkg-deb（打包，Debian 系自带）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="$(awk -F'"' '/^var version =/{print $2; exit}' main.go)"
VERSION="${VERSION:-0.0.0}"
echo ">>> 版本 $VERSION"
mkdir -p build/deb

# build_one <webkit> <depends> <suffix>
build_one() {
  local webkit="$1" depends="$2" suffix="$3"
  local bin="build/foundry-quota-sentinel-wk${suffix}"

  if [ "${SKIP_BUILD:-0}" != "1" ]; then
    echo ">>> 编 webkit ${webkit} 二进制 -> $bin"
    OUTPUT="$bin" WEBKIT="$webkit" scripts/build-linux.sh
  fi
  [ -f "$bin" ] || { echo "缺二进制 $bin" >&2; exit 1; }

  local out="build/foundry-quota-sentinel_${VERSION}_amd64-webkit${suffix}.deb"
  scripts/pack-deb.sh "$bin" "$VERSION" "$depends" "$webkit" "$out"
}

build_one 4.0 "libwebkit2gtk-4.0-37, libgtk-3-0"                40
build_one 4.1 "libwebkit2gtk-4.1-0, libgtk-3-0t64 | libgtk-3-0" 41

echo
echo ">>> 完成，两个 deb："
ls -1 build/*.deb
