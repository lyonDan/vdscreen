#!/bin/zsh
# 集成测试：真的创建 / 切换虚拟显示器，用来验证 HiDPI、横竖切换在当前 macOS 上是否仍然成立。
# 默认只测两种分辨率 × 横竖来回（约 9 次重建、1 分钟左右）；
# `--all` 才逐条验证全部预设（每次重建 5–10 秒，全量再多 2–3 分钟），留给 macOS 升级后的回归检查。
# 使用固定的独立测试服务、配置与日志；结束后（含 Ctrl-C）移除测试屏。
# 首次运行可能留下 1 份 ICC，后续运行复用；不使用时间戳或随机显示器身份。
# 只能在有图形会话的本机运行，CI 里没有可用的显示环境，所以不在 CI 中执行。
#
# 用法: tests/integration.sh --yes [--all]
cd "$(dirname "$0")/.." || exit 2
[[ "${1:-}" == "--yes" || "${2:-}" == "--yes" ]] || { print -r -- "会切换真实的虚拟显示器。确认请加 --yes"; exit 2 }
ALL=0
[[ "${1:-}" == "--all" || "${2:-}" == "--all" ]] && ALL=1
ROOT="$PWD"
# 始终编译当前源码，避免测到安装版或旧核心。
./build.sh >/dev/null || exit 1

setopt extended_glob       # ${var%%[[:space:]]#} 修剪空白需要它
TEST_LABEL=io.github.lyondan.vdscreen.integration
if [[ -f "$HOME/Library/LaunchAgents/$TEST_LABEL.plist" ]] || launchctl print "gui/$(id -u)/$TEST_LABEL" >/dev/null 2>&1; then
  print -ru2 -- "测试服务已存在，请先结束另一次集成测试。"
  exit 2
fi
TMP="$(mktemp -d)" || exit 1
export VDS_CONFIG_DIR="$TMP/config"
mkdir -p "$VDS_CONFIG_DIR"
cat > "$VDS_CONFIG_DIR/config" <<CFG
LABEL="$TEST_LABEL"
CORE="$ROOT/vdscreen-core"
ORIENTATION="auto"
LOG_PATH="$TMP/core.log"
ERROR_PATH="$TMP/core.err"
CFG
V() { "$ROOT/vdscreen" "$@"; }
cleanup() {
  V off >/dev/null 2>&1
  if launchctl print "gui/$(id -u)/$TEST_LABEL" >/dev/null 2>&1; then
    print -ru2 -- "测试服务未能移除，配置与日志保留在 $TMP"
    return 1
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

pass=0; fail=0
ok()  { pass=$((pass + 1)); print -r -- "  ✓ $1"; }
bad() { fail=$((fail + 1)); print -r -- "  ✗ $1"; }
check() { # check <描述> <期望> <实际>
  if [[ "$2" == "$3" ]]; then ok "$1 = $3"; else bad "$1: 期望「$2」实际「$3」"; fi
}
state_size() { local s="$(V state)"; print -r -- "${s##* }"; }
is_hidpi() { [[ "$1" == *"实际:"*"—— HiDPI"* ]]; }

expected_uuid=""
check_identity() {
  local uuid="$(sed -n 's/^身份：.*uuid=//p' "$TMP/core.log" | tail -1)"
  if [[ -z "$uuid" ]]; then bad "没有读到显示器 UUID"; return; fi
  [[ -n "$expected_uuid" ]] || expected_uuid="$uuid"
  check "切换后保持显示器 UUID" "$expected_uuid" "$uuid"
  local profiles=(/Library/ColorSync/Profiles/Displays/*-${uuid}.icc(N))
  check "同一身份只有一份 ICC" 1 "${#profiles}"
}
TAG="VDScreen integration"

print -r -- "== 1. 两种分辨率 × 横竖来回，方向锁定换尺寸后保持 =="
out="$(V on 1133x744 "$TAG" 2>&1)"
check "[1133x744] 画布尺寸" 1133x744 "$(state_size)"
is_hidpi "$out" && ok "[1133x744] HiDPI" || bad "[1133x744] 不是 HiDPI"
check_identity
out="$(V orientation 竖屏 2>&1)"
check "横→竖" 744x1133 "$(state_size)"
is_hidpi "$out" && ok "[744x1133] HiDPI" || bad "[744x1133] 不是 HiDPI"
check_identity
V on 804x1748 "$TAG phone" >/dev/null 2>&1; check "锁竖时竖屏请求原样" 804x1748 "$(state_size)"
check_identity
out="$(V orientation 横屏 2>&1)"
check "竖→横" 1748x804 "$(state_size)"
is_hidpi "$out" && ok "[1748x804] HiDPI" || bad "[1748x804] 不是 HiDPI"
check_identity
V on 744x1133 "$TAG" >/dev/null 2>&1; check "锁横时竖屏请求摆成横屏" 1133x744 "$(state_size)"
check_identity
V orientation auto >/dev/null 2>&1
V on 744x1133 "$TAG" >/dev/null 2>&1; check "auto 恢复跟随请求" 744x1133 "$(state_size)"
check_identity
if (( ALL )); then
  print -r -- "== 1b. (--all) 全部预设逐条验证 =="
  # 不使用管道子 shell，保证失败计数保留。
  while IFS= read -r line; do
    [[ "$line" =~ '^[[:space:]]*(#|$)' || "$line" != *=* ]] && continue
    name="${${line%%=*}%%[[:space:]]#}"; size="${${line#*=}//[[:space:]]/}"
    out="$(V preset "$name" 2>&1)"
    check "[$name] 画布尺寸" "$size" "$(state_size)"
    is_hidpi "$out" && ok "[$name] HiDPI" || bad "[$name] 不是 HiDPI"
    check_identity
  done < <(V presets)
fi

print -r -- "== 2. 低于高度下限的尺寸（以请求尺寸为准重摆）=="
V on 874x402 "$TAG small" >/dev/null 2>&1; check "874x402 被放大" 1044x480 "$(state_size)"
check_identity
V orientation 竖屏 >/dev/null 2>&1; check "锁竖后以请求尺寸为准" 402x874 "$(state_size)"
check_identity
V orientation 横屏 >/dev/null 2>&1; check "再切回原路返回" 1044x480 "$(state_size)"
check_identity
V orientation auto >/dev/null 2>&1
out="$(V on 1133x744 "$TAG" 2>&1)"
check "小尺寸后恢复正常尺寸" 1133x744 "$(state_size)"
is_hidpi "$out" && ok "退回 1:1 后能恢复 HiDPI" || bad "退回 1:1 后未恢复 HiDPI"
check_identity

print -r -- "== 3. 关闭 =="
V off >/dev/null 2>&1; check "off 后状态" off "$(V state)"

print -r -- "集成测试: 通过 $pass, 失败 $fail"
(( fail == 0 ))
