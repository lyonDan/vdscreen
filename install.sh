#!/bin/zsh
# 一键安装 VDScreenBar（菜单栏 App + 命令行工具），从最新 Release 下载预编译包。
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/lyonDan/vdscreen/main/install.sh | zsh
# 也可先下载再执行：./install.sh
set -euo pipefail

REPO="lyonDan/vdscreen"
BIN_DIR="$HOME/bin"
APP_DIR="$HOME/Applications"

say() { printf '%s\n' "$*"; }
die() { printf '安装失败: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "需要 curl（macOS 自带）"

# 最新版本号：跟随 releases/latest 的跳转地址
latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
ver="${latest_url##*/}"
[[ "$ver" == v* ]] || die "无法确定最新版本（$latest_url）"
num="${ver#v}"
say "► 最新版本 $ver"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "► 下载 VDScreenBar-$num-arm64.zip …"
zip="$tmp/VDScreenBar-$num-arm64.zip"
curl -fsSL -o "$zip" "https://github.com/$REPO/releases/download/$ver/VDScreenBar-$num-arm64.zip"
ditto -x -k "$zip" "$tmp"
app="$tmp/VDScreenBar.app"
[[ -d "$app" ]] || die "压缩包里没有 VDScreenBar.app"

# 包为 Developer ID 签名 + Apple 公证；安装前再校验一次
spctl --assess --type execute --verbose=2 "$app" >/dev/null \
  || die "Gatekeeper 校验未通过，已中止（不会安装未公证的程序）"

# 菜单栏 App
killall vdscreen-bar 2>/dev/null || true
mkdir -p "$APP_DIR"
rm -rf "$APP_DIR/VDScreenBar.app"
cp -R "$app" "$APP_DIR/"
say "► 菜单栏 App: $APP_DIR/VDScreenBar.app"

# 命令行工具（App Resources 里带着完整的 vdscreen + 核心）
mkdir -p "$BIN_DIR"
cp "$app/Contents/Resources/vdscreen" "$app/Contents/Resources/vdscreen-core" "$BIN_DIR/"
chmod +x "$BIN_DIR/vdscreen" "$BIN_DIR/vdscreen-core"
say "► 命令行: $BIN_DIR/vdscreen"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "  提示: $BIN_DIR 不在 PATH，把下面这行加进 ~/.zshrc 后重开终端："
     say "    export PATH=\"\$HOME/bin:\$PATH\"" ;;
esac

say "► 完成。启动菜单栏 App：open $APP_DIR/VDScreenBar.app"
say "  命令行试用：$BIN_DIR/vdscreen presets"
