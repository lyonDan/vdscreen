#!/bin/zsh
# 集成测试：真的创建 / 切换虚拟显示器，用来验证 HiDPI、横竖切换在当前 macOS 上是否仍然成立。
# 默认只测两种分辨率 × 横竖来回（约 9 次重建、1 分钟左右）；
# `--all` 才逐条验证全部预设（每次重建 5–10 秒，全量再多 2–3 分钟），留给 macOS 升级后的回归检查。
# 运行期间屏幕会闪断数次；结束后（含 Ctrl-C）会恢复到运行前的状态。
# 只能在有图形会话的本机运行，CI 里没有可用的显示环境，所以不在 CI 中执行。
#
# 用法: tests/integration.sh --yes [--all]
cd "$(dirname "$0")/.." || exit 2
[[ "${1:-}" == "--yes" || "${2:-}" == "--yes" ]] || { print -r -- "会切换真实的虚拟显示器。确认请加 --yes"; exit 2 }
ALL=0
[[ "${1:-}" == "--all" || "${2:-}" == "--all" ]] && ALL=1
[[ -x ./vdscreen-core ]] || ./build.sh >/dev/null

setopt extended_glob       # ${var%%[[:space:]]#} 修剪空白需要它
V=./vdscreen
orig="$($V state)"
restore() {
  if [[ "$orig" == on\ * ]]; then
    local size="${orig##* }" name="${${orig#on }% *}"
    $V on "$size" "$name" >/dev/null 2>&1
  else
    $V off >/dev/null 2>&1
  fi
  print -r -- "已恢复: $($V state)"
}
trap restore EXIT
trap 'exit 130' INT TERM

pass=0; fail=0
ok()  { pass=$((pass + 1)); print -r -- "  ✓ $1"; }
bad() { fail=$((fail + 1)); print -r -- "  ✗ $1"; }
check() { # check <描述> <期望> <实际>
  if [[ "$2" == "$3" ]]; then ok "$1 = $3"; else bad "$1: 期望「$2」实际「$3」"; fi
}
state_size() { local s="$($V state)"; print -r -- "${s##* }"; }
is_hidpi() { [[ "$1" == *"实际:"*"—— HiDPI"* ]]; }

# 每个尺寸用带时间戳的唯一名字建屏：macOS 会记住每个显示器身份（名字+尺寸）曾用过的模式，
# 某身份曾以非 HiDPI 使用后，它的模式表里就不再出现 HiDPI 变体。用过的名字重测会误报
# 「不是 HiDPI」，其实只是这个身份被系统「烧掉」了，换成新名字即恢复。
TAG="itest-$(date +%H%M%S)"

print -r -- "== 1. 两种分辨率 × 横竖来回，方向锁定换尺寸后保持 =="
out="$($V on 1133x744 "$TAG A" 2>&1)"
check "[1133x744] 画布尺寸" 1133x744 "$(state_size)"
is_hidpi "$out" && ok "[1133x744] HiDPI" || bad "[1133x744] 不是 HiDPI"
out="$($V orientation 竖屏 2>&1)"
check "横→竖" 744x1133 "$(state_size)"
is_hidpi "$out" && ok "[744x1133] HiDPI" || bad "[744x1133] 不是 HiDPI"
$V on 804x1748 "$TAG B" >/dev/null 2>&1; check "锁竖时竖屏请求原样" 804x1748 "$(state_size)"
out="$($V orientation 横屏 2>&1)"
check "竖→横" 1748x804 "$(state_size)"
is_hidpi "$out" && ok "[1748x804] HiDPI" || bad "[1748x804] 不是 HiDPI"
$V on 744x1133 "$TAG A" >/dev/null 2>&1; check "锁横时竖屏请求摆成横屏" 1133x744 "$(state_size)"
$V orientation auto >/dev/null 2>&1
$V on 744x1133 "$TAG A" >/dev/null 2>&1; check "auto 恢复跟随请求" 744x1133 "$(state_size)"
if (( ALL )); then
  print -r -- "== 1b. (--all) 全部预设逐条验证 =="
  $V presets | while IFS= read -r line; do
    [[ "$line" =~ '^[[:space:]]*(#|$)' || "$line" != *=* ]] && continue
    name="${${line%%=*}%%[[:space:]]#}"; size="${${line#*=}//[[:space:]]/}"
    out="$($V preset "$name" 2>&1)"
    check "[$name] 画布尺寸" "$size" "$(state_size)"
    is_hidpi "$out" && ok "[$name] HiDPI" || bad "[$name] 不是 HiDPI"
  done
fi

print -r -- "== 2. 低于高度下限的尺寸（以请求尺寸为准重摆）=="
$V on 874x402 "$TAG C" >/dev/null 2>&1; check "874x402 被放大" 1044x480 "$(state_size)"
$V orientation 竖屏 >/dev/null 2>&1; check "锁竖后以请求尺寸为准" 402x874 "$(state_size)"
$V orientation 横屏 >/dev/null 2>&1; check "再切回原路返回" 1044x480 "$(state_size)"
$V orientation auto >/dev/null 2>&1

print -r -- "== 3. 关闭 =="
$V off >/dev/null 2>&1; check "off 后状态" off "$($V state)"

print -r -- "集成测试: 通过 $pass, 失败 $fail"
(( fail == 0 ))
