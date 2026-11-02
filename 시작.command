#!/bin/bash
# 터치패드 음량 빌드(소스 바뀌었을 때만) + 실행
cd "$(dirname "$0")"
APP="터치패드.app"
BIN="$APP/Contents/MacOS/touchpad"

if [ ! -x "$BIN" ] || [ TouchPad.swift -nt "$BIN" ]; then
  mkdir -p "$APP/Contents/MacOS"
  swiftc -O -swift-version 5 TouchPad.swift -o "$BIN" || exit 1
  "$BIN" --test || exit 1
  cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.touchpad.volume</string>
  <key>CFBundleName</key><string>터치패드</string>
  <key>CFBundleExecutable</key><string>touchpad</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
  codesign -s - --force "$APP"
fi

pkill -x touchpad
open "$APP"
