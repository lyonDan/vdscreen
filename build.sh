#!/bin/zsh
# 编译 vdscreen 核心 + 菜单栏 App（只需系统自带的 clang / swiftc）
set -euo pipefail
cd "$(dirname "$0")"

clang -fobjc-arc -framework Foundation -framework AppKit -framework CoreGraphics \
      -o vdscreen-core vdscreen.m
echo "核心:     $(pwd)/vdscreen-core"

APP="VDScreenBar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp vdscreen "$APP/Contents/Resources/vdscreen"
cp vdscreen-core "$APP/Contents/Resources/vdscreen-core"
chmod +x "$APP/Contents/Resources/vdscreen" "$APP/Contents/Resources/vdscreen-core"

swiftc -O -parse-as-library -o "$APP/Contents/MacOS/vdscreen-bar" vdscreen-bar.swift \
       -framework SwiftUI -framework AppKit

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>VDScreenBar</string>
  <key>CFBundleDisplayName</key><string>vdscreen</string>
  <key>CFBundleIdentifier</key><string>com.local.vdscreen.bar</string>
  <key>CFBundleExecutable</key><string>vdscreen-bar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo "菜单栏App: $(pwd)/$APP"
