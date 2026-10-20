#!/bin/sh
# Builds agentmode-helper and AgentMode.app next to this script.
# Pass --install to link agent-mode into ~/.local/bin and copy the app to /Applications.
set -e
cd "$(dirname "$0")"

swiftc -O -swift-version 5 helper.swift -o agentmode-helper
codesign --force -s - agentmode-helper
chmod +x agent-mode

APP=AgentMode.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"  # made with ~/.local/bin/make-app-icon

swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/AgentMode"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.agentmode</string>
  <key>CFBundleName</key><string>AgentMode</string>
  <key>CFBundleExecutable</key><string>AgentMode</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"
echo "Built $APP"

if [ "$1" = "--install" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$PWD/agent-mode" "$HOME/.local/bin/agent-mode"
  rm -rf "/Applications/$APP"
  cp -R "$APP" /Applications/
  echo "Linked ~/.local/bin/agent-mode, installed /Applications/$APP"
fi
