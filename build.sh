#!/bin/zsh
# 编译 vdscreen（只需系统自带的 clang，无第三方依赖）
set -euo pipefail
cd "$(dirname "$0")"

clang -fobjc-arc -framework Foundation -framework AppKit -framework CoreGraphics \
      -o vdscreen-core vdscreen.m
echo "编译完成: $(pwd)/vdscreen-core"
