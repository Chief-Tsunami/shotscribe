#!/bin/zsh
# Bundle the menu bar target into dist/ShotScribe.app.
#
# Plain run:                       ad-hoc signed, local use only.
# APPLE_NOTARY_PROFILE=<profile>:  Developer ID + hardened runtime + secure
#                                  timestamp, notarized + stapled (app AND a
#                                  distributable DMG). Mirrors Navi's ship
#                                  stage; the profile is a `xcrun notarytool
#                                  store-credentials` keychain profile.
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

if [ -z "${APPLE_NOTARY_PROFILE:-}" ]; then
    codesign --force -s - "$APP"
    echo "==> packaged $APP (ad-hoc; set APPLE_NOTARY_PROFILE to ship)"
    exit 0
fi

# ---- Apple ship stage ------------------------------------------------------

SIGN_ID="${SHOTSCRIBE_SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
[ -n "$SIGN_ID" ] || { echo "error: no Developer ID Application identity"; exit 1; }

echo "==> APPLE: signing with '$SIGN_ID' (hardened runtime + timestamp)"
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP" && echo "==> signature verified"

echo "==> APPLE: notarizing the app (profile: $APPLE_NOTARY_PROFILE)"
ZIP="dist/ShotScribe-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
rm -f "$ZIP"
xcrun stapler staple "$APP"

echo "==> APPLE: building + notarizing the DMG"
DMG="dist/ShotScribe-${VERSION}.dmg"
STAGE="dist/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ShotScribe" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> shipped: $APP + $DMG (signed, notarized, stapled)"
spctl -a -vv "$APP" 2>&1 | tail -2
