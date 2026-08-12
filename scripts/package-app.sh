#!/bin/zsh
# Bundle the menu bar target into dist/ShotScribe.app (ad-hoc signed, no Dock
# icon). Local packaging only — notarization is a later, separate step.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="0.4.0"

echo "==> swift build -c release (shotscribe-menubar)"
swift build -c release --product shotscribe-menubar

APP="dist/ShotScribe.app"
BIN=".build/release/shotscribe-menubar"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/ShotScribe"
cp assets/ShotScribe.icns "$APP/Contents/Resources/ShotScribe.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ShotScribe</string>
    <key>CFBundleIdentifier</key><string>com.joshvanorden.shotscribe</string>
    <key>CFBundleName</key><string>ShotScribe</string>
    <key>CFBundleDisplayName</key><string>ShotScribe</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>ShotScribe</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT — Josh VanOrden</string>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "==> packaged $APP"
