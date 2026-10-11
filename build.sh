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
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/Resources/vdscreen" "$APP/Contents/Resources/vdscreen-core"

swiftc -O -o "$APP/Contents/MacOS/vdscreen-bar" vdscreen-bar.swift \
       -framework AppKit -framework Carbon -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>VDScreenBar</string>
  <key>CFBundleDisplayName</key><string>vdscreen</string>
  <key>CFBundleIdentifier</key><string>com.local.vdscreen.bar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>vdscreen-bar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.local.vdscreen.bar</string>
      <key>CFBundleURLSchemes</key><array><string>vdscreen</string></array>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 清掉扩展属性后做 ad-hoc 签名，把 Info.plist 与图标资源封进 bundle；
# 否则系统可能不认 CFBundleIconFile，Finder/Dock 里图标一直是空白
xattr -cr "$APP"
codesign --force --deep -s - "$APP"

echo "菜单栏App: $(pwd)/$APP"
