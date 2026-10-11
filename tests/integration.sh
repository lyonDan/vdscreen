#!/bin/zsh
# 集成测试：真的创建 / 切换虚拟显示器，用来验证 HiDPI、横竖切换、界面缩放在当前 macOS 上是否仍然成立。
# 运行期间屏幕会闪断数次、约 2–3 分钟；结束后（含 Ctrl-C）会恢复到运行前的状态。
# 只能在有图形会话的本机运行，CI 里没有可用的显示环境，所以不在 CI 中执行。
#
# 用法: tests/integration.sh --yes
cd "$(dirname "$0")/.." || exit 2
[[ "${1:-}" == "--yes" ]] || { print -r -- "会切换真实的虚拟显示器。确认请加 --yes"; exit 2 }
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
is_soft()  { [[ "$1" == *"实际:"*"非 HiDPI"* ]]; }

print -r -- "== 1. 全部预设：尺寸正确，且预测能 HiDPI 的确实是 HiDPI =="
$V presets | while IFS= read -r line; do
  [[ "$line" =~ '^[[:space:]]*(#|$)' || "$line" != *=* ]] && continue
  name="${${line%%=*}%%[[:space:]]#}"; size="${${line#*=}//[[:space:]]/}"
  out="$($V preset "$name" 2>&1)"
  check "[$name] 画布尺寸" "$size" "$(state_size)"
  smax="${$($V zoominfo)##* }"
  if (( smax >= 1.0 )); then
    is_hidpi "$out" && ok "[$name] 预测 HiDPI → 实际 HiDPI" || bad "[$name] 预测 HiDPI，实际不是"
  else
    print -r -- "  · [$name] 模型预测不会 HiDPI（清晰上限 $smax），不作断言"
  fi
done

print -r -- "== 2. 横竖切换往返 =="
$V preset "iPhone 18 Pro" >/dev/null 2>&1
out="$($V rotate 2>&1)"; check "竖→横" 1748x804 "$(state_size)"; is_hidpi "$out" && ok "横屏 HiDPI" || bad "横屏不是 HiDPI"
$V rotate >/dev/null 2>&1; check "横→竖" 804x1748 "$(state_size)"

print -r -- "== 3. 低于高度下限的尺寸 =="
$V on 874x402 "itest" >/dev/null 2>&1; check "874x402 被放大" 1044x480 "$(state_size)"
$V rotate >/dev/null 2>&1;             check "rotate 以请求尺寸为准" 402x874 "$(state_size)"
$V rotate >/dev/null 2>&1;             check "再 rotate 原路返回" 1044x480 "$(state_size)"

print -r -- "== 4. 界面缩放 =="
$V preset "iPhone 18 Pro" >/dev/null 2>&1
out="$($V zoom max 2>&1)";  check "zoom max 画布" 670x1457 "$(state_size)"; is_hidpi "$out" && ok "清晰上限处仍是 HiDPI" || bad "清晰上限处不是 HiDPI（预测模型失效，需重新实测）"
out="$($V zoom 125 2>&1)";  check "zoom 125 画布" 643x1398 "$(state_size)"; is_soft "$out" && ok "越过上限如实标注为非 HiDPI" || bad "125% 没有如实标注"
$V rotate >/dev/null 2>&1;  check "rotate 保持缩放" 1398x643 "$(state_size)"
$V zoom reset >/dev/null 2>&1; check "zoom reset" 1748x804 "$(state_size)"
$V zoom reset 2>&1 | grep -q "无需改动" && ok "重复设置同一缩放是空操作" || bad "重复设置没有被识别"
$V preset "iPhone 18 Pro" >/dev/null 2>&1; z="$($V zoominfo | cut -d' ' -f1)"; (( z == 1 )) && ok "换预设还原 100%" || bad "换预设没有还原缩放（当前 $z）"

print -r -- "== 5. 关闭 =="
$V off >/dev/null 2>&1; check "off 后状态" off "$($V state)"

print -r -- "集成测试: 通过 $pass, 失败 $fail"
(( fail == 0 ))
