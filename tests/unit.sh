#!/bin/zsh
# 单元测试：只测 CLI 里的纯逻辑和不碰显示器的命令，不创建虚拟屏，几秒内跑完。
# 用法: tests/unit.sh        （失败时退出码非 0）
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"          # 隔离配置/预设/plist，绝不碰真实环境
mkdir -p "$HOME/.config/vdscreen"
# 即使某条命令误走到"开启"分支，也只会操作一个不存在的 launchd 标签、启动一个空壳核心，
# 不会碰到真实的虚拟屏（教训：曾因没隔离 LABEL，测试把线上屏切成了竖屏）
cat > "$HOME/.config/vdscreen/config" <<CFG
LABEL="vdscreen.unit-test.$$"
CORE="/usr/bin/true"
CFG

setopt extended_glob
pass=0; fail=0
eq() {   # eq <描述> <期望> <实际>
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1))
  else fail=$((fail + 1)); print -r -- "✗ $1: 期望「$2」实际「$3」"; fi
}

VDS_LIB=1 source "$ROOT/vdscreen"
set +e +u +o pipefail            # 被加载脚本里的 set -euo 会影响测试本身

# ── normalize_size：高度下限 480 ──
eq "正常尺寸不变"        1133x744  "$(normalize_size 1133x744 2>/dev/null)"
eq "竖屏手机不变"        804x1748  "$(normalize_size 804x1748 2>/dev/null)"
eq "矮屏等比放大"        1044x480  "$(normalize_size 874x402 2>/dev/null)"
eq "恰好 480 不动"       1000x480  "$(normalize_size 1000x480 2>/dev/null)"
eq "无法解析原样返回"    abc       "$(normalize_size abc 2>/dev/null)"

# ── apply_orientation：方向锁定 ──
eq "auto 原样"          1133x744  "$(apply_orientation 1133x744)"
ORIENTATION="landscape"; eq "锁横：横屏不动" 1133x744 "$(apply_orientation 1133x744)"
ORIENTATION="landscape"; eq "锁横：竖屏转横" 1748x804 "$(apply_orientation 804x1748)"
ORIENTATION="portrait";  eq "锁竖：竖屏不动" 804x1748 "$(apply_orientation 804x1748)"
ORIENTATION="portrait";  eq "锁竖：横屏转竖" 744x1133 "$(apply_orientation 1133x744)"
ORIENTATION="landscape"; eq "方形尺寸不动"   800x800  "$(apply_orientation 800x800)"
ORIENTATION="portrait";  eq "无法解析原样"   abc      "$(apply_orientation abc)"
ORIENTATION="auto"

# ── apply_zoom ──
eq "倍数 1 原样"         804x1748  "$(apply_zoom 804x1748 1)"
eq "倍数 1 保留奇数"     1133x745  "$(apply_zoom 1133x745 1)"
eq "125% 缩小画布"       643x1398  "$(apply_zoom 804x1748 1.25)"
eq "50% 画布翻倍"        1608x3496 "$(apply_zoom 804x1748 0.5)"
eq "横屏缩放"            1398x643  "$(apply_zoom 1748x804 1.25)"

# ── sharp_zoom_max：HiDPI 清晰上限预测（经验模型，改系数时要同步 README）──
eq "手机竖屏上限"        1.20  "$(sharp_zoom_max 804x1748)"
eq "手机横屏上限"        1.34  "$(sharp_zoom_max 1748x804)"
eq "iPad mini 横屏上限"  1.24  "$(sharp_zoom_max 1133x744)"
eq "iPad mini 竖屏上限"  1.11  "$(sharp_zoom_max 744x1133)"
eq "1080p 上限"          1.80  "$(sharp_zoom_max 1920x1080)"
eq "非法尺寸回落 1"      1.00  "$(sharp_zoom_max abc)"

# ── parse_zoom ──
eq "整数百分数"          1.25  "$(parse_zoom 125)"
eq "带 % 号"             1.25  "$(parse_zoom 125%)"
eq "小数倍数"            1.25  "$(parse_zoom 1.25)"
eq "50%"                 0.5   "$(parse_zoom 50%)"
parse_zoom abc >/dev/null 2>&1;   eq "字母非法"   1 $?
parse_zoom "1;rm" >/dev/null 2>&1; eq "注入非法"  1 $?
parse_zoom "" >/dev/null 2>&1;    eq "空串非法"   1 $?

# ── next_zoom：沿档位走，且先停在清晰上限 ──
eq "放大到下一档"            1.1   "$(next_zoom in 1 1.2)"
eq "放大先停在清晰上限"      1.2   "$(next_zoom in 1.1 1.2)"
eq "越过上限后继续下一档"    1.25  "$(next_zoom in 1.2 1.2)"
eq "缩小到上一档"            0.9   "$(next_zoom out 1 1.2)"
eq "从略软区缩小先回上限"    1.2   "$(next_zoom out 1.25 1.2)"
eq "缩小有下限"              0.5   "$(next_zoom out 0.5 1.2)"
eq "放大有上限"              2.0   "$(next_zoom in 2.0 1.2)"

# ── xml_escape ──
eq "XML 转义" 'R&amp;D &lt;x&gt;' "$(xml_escape 'R&D <x>')"

# ── plist 往返：特殊字符名字、请求尺寸、缩放 ──
PLIST="$TMP/t.plist"
SIZE=670x1457; NAME='R&D <测试> "x"'; REQUESTED=804x1748; ZOOM=1.2
write_plist
plutil -lint "$PLIST" >/dev/null 2>&1; eq "plist 是合法 XML" 0 $?
eq "读回名字（含特殊字符）" "$NAME"   "$(current_name)"
eq "读回画布尺寸"           670x1457  "$(current_size)"
eq "读回请求尺寸"           804x1748  "$(current_requested)"
eq "读回缩放"               1.2       "$(current_zoom)"
unset REQUESTED; ZOOM=1; write_plist
eq "无请求尺寸时回落到画布" 670x1457  "$(current_requested)"
eq "默认缩放 1"             1         "$(current_zoom)"
PLIST="$TMP/none.plist"
eq "没有 plist 时缩放 1"    1         "$(current_zoom)"

# ── 预设：默认文件格式 ──
ensure_presets
count=0; badfmt=0; names=()
while IFS= read -r line; do
  [[ "$line" =~ '^[[:space:]]*(#|$)' ]] && continue
  name="${${line%%=*}%%[[:space:]]#}"; size="${${line#*=}//[[:space:]]/}"
  count=$((count + 1)); names+=("$name")
  [[ "$size" =~ '^[0-9]+x[0-9]+$' ]] || { badfmt=$((badfmt + 1)); print -r -- "  坏预设: $line"; }
done < "$PRESETS"
eq "默认预设数量" 11 "$count"
eq "预设尺寸格式都合法" 0 "$badfmt"
uniq=(${(u)names}); eq "预设名不重复" "$count" "${#uniq}"
eq "已移除 iPhone SE"    ""       "$(preset_size 'iPhone SE (3rd)')"
eq "已移除 iPhone Air"   ""       "$(preset_size 'iPhone Air')"
eq "按名字查预设"       1133x744 "$(preset_size 'iPad mini 7')"
eq "常见显示器分辨率"    1600x900 "$(preset_size '1600x900')"
eq "名字含斜杠的预设"   1180x820 "$(preset_size 'iPad Air 11 / iPad 10-11')"
eq "查不到预设返回空"   ""       "$(preset_size '不存在')"

# ── LaunchAgent 标签：默认、旧版兼容、配置覆盖 ──
label_of() { HOME="$1" VDS_LIB=1 zsh -c "source '$ROOT/vdscreen'; print -r -- \$LABEL"; }
fresh="$TMP/lbl-fresh"; mkdir -p "$fresh"
eq "默认标签" io.github.lyondan.vdscreen "$(label_of "$fresh")"
legacy="$TMP/lbl-legacy"; mkdir -p "$legacy/Library/LaunchAgents"; : > "$legacy/Library/LaunchAgents/com.local.vdscreen.ipadmini7.plist"
eq "旧标签的 plist 还在时沿用旧标签" com.local.vdscreen.ipadmini7 "$(label_of "$legacy")"
both="$TMP/lbl-both"; mkdir -p "$both/Library/LaunchAgents"
: > "$both/Library/LaunchAgents/com.local.vdscreen.ipadmini7.plist"; : > "$both/Library/LaunchAgents/io.github.lyondan.vdscreen.plist"
eq "新旧并存时用新标签" io.github.lyondan.vdscreen "$(label_of "$both")"
custom="$TMP/lbl-custom"; mkdir -p "$custom/.config/vdscreen" "$custom/Library/LaunchAgents"
print 'LABEL="my.label"' > "$custom/.config/vdscreen/config"; : > "$custom/Library/LaunchAgents/com.local.vdscreen.ipadmini7.plist"
eq "配置里的 LABEL 优先" my.label "$(label_of "$custom")"
HOME="$custom" zsh "$ROOT/vdscreen" set size 1280x800 >/dev/null 2>&1
eq "set 保留自定义 LABEL" 1 "$(grep -c '^LABEL="my.label"' "$custom/.config/vdscreen/config")"
HOME="$legacy" zsh "$ROOT/vdscreen" set size 1280x800 >/dev/null 2>&1
eq "set 不会把沿用的旧标签固化进配置" 0 "$(grep -c '^LABEL=' "$legacy/.config/vdscreen/config")"

# ── 不碰显示器的命令（子进程跑，HOME 已隔离 → 没有 plist → 视为未开启）──
out="$(zsh "$ROOT/vdscreen" state 2>&1)";           eq "state（未开启）" off "$out"
zsh "$ROOT/vdscreen" zoom >/dev/null 2>&1;          eq "未开启时 zoom 报错" 1 $?
zsh "$ROOT/vdscreen" rotate >/dev/null 2>&1;        eq "未开启时 rotate 报错" 1 $?
zsh "$ROOT/vdscreen" main >/dev/null 2>&1;           eq "未开启时 main 报错" 1 $?
zsh "$ROOT/vdscreen" preset 不存在 >/dev/null 2>&1; eq "未知预设报错" 1 $?
zsh "$ROOT/vdscreen" bogus >/dev/null 2>&1;         eq "未知命令报错" 1 $?
eq "help 有内容" 1 "$(zsh "$ROOT/vdscreen" help | grep -c 'vdscreen on')"
eq "presets 命令可用" 1 "$(zsh "$ROOT/vdscreen" presets | grep -c 'iPhone 18 Pro  ')"

print -r -- "单元测试: 通过 $pass, 失败 $fail"
(( fail == 0 ))
