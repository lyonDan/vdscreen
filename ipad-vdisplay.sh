#!/bin/zsh
# iPad mini 7 虚拟屏开关（封装 vdscreen，无需 BetterDisplay / 任何第三方依赖）
#
#   ./ipad-vdisplay.sh on      启动虚拟屏（背板 2266x1488 / UI 1133x744）
#   ./ipad-vdisplay.sh off     关闭
#   ./ipad-vdisplay.sh status  查看状态
#
# 首次使用先编译: ./build.sh
#
# 用 LaunchAgent 托管而不是 nohup：虚拟屏的寿命等于创建它的进程寿命，
# 而 nohup 出来的子进程会随终端会话一起被回收，LaunchAgent 由 launchd 持有，
# 跨终端、跨登录都稳定。只要 plist 还在，登录时会自动拉起；
# off 会连 plist 一起删除，确保"关闭"是真的关闭。

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/vdscreen"
LABEL="com.local.vdscreen.ipadmini7"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
NAME="iPad mini 7"
SIZE="1133x744"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

write_plist() {
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>$SIZE</string>
    <string>$NAME</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>StandardOutPath</key><string>/tmp/ipad-vdisplay.log</string>
  <key>StandardErrorPath</key><string>/tmp/ipad-vdisplay.err</string>
</dict>
</plist>
PLIST_EOF
}

loaded() { launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; }

status() {
  if loaded; then
    echo "LaunchAgent 已加载 ($LABEL)"
  else
    echo "LaunchAgent 未加载"
  fi
  local line
  line=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -A 3 "^        $NAME:" | head -4)
  [[ -n "$line" ]] && echo "$line" || echo "  虚拟屏未出现"
}

case "${1:-status}" in
  on)
    [[ -x "$BIN" ]] || { echo "缺少 $BIN，请先运行 ./build.sh" >&2; exit 1; }
    write_plist
    if loaded; then
      launchctl kickstart -k "$DOMAIN/$LABEL"
    else
      launchctl bootstrap "$DOMAIN" "$PLIST"
    fi
    sleep 3
    cat /tmp/ipad-vdisplay.log 2>/dev/null || true
    cat /tmp/ipad-vdisplay.err 2>/dev/null || true
    status
    ;;
  off)
    if loaded; then
      launchctl bootout "$DOMAIN/$LABEL"
    fi
    rm -f "$PLIST"
    echo "已关闭（LaunchAgent 已移除，登录不会再自动启动）"
    sleep 2
    ;;
  status) status ;;
  *) echo "用法: $0 {on|off|status}" >&2; exit 1 ;;
esac
