#!/bin/sh
# Builds build/Lupita.app (menu bar app). No Xcode needed.
# Signing: a self-signed "Lupita Dev" code-signing certificate in the login keychain (any case)
# keeps macOS permissions across rebuilds. Without it, the app is signed ad-hoc and macOS
# forgets the permissions on every build. Override with LUPITA_SIGN_IDENTITY.
# "Refs Dev" is still accepted: it was the certificate name before the rename.
set -e
cd "$(dirname "$0")/.."
swift build -c release --product LupitaApp
APP=build/Lupita.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LupitaApp "$APP/Contents/MacOS/LupitaApp"
# App icon: Lupita at rest (scripts/make-icon.swift draws it from docs/brand/guide.md).
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.manubarranco.lupita</string>
  <key>CFBundleName</key><string>Lupita</string>
  <key>CFBundleDisplayName</key><string>Lupita</string>
  <key>CFBundleExecutable</key><string>LupitaApp</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
IDENTITY="${LUPITA_SIGN_IDENTITY:-$(security find-identity -p codesigning | grep -iE '"(Lupita|Refs) Dev"' | head -1 | awk '{print $2}')}"
codesign --force --sign "${IDENTITY:--}" "$APP"
[ -n "$IDENTITY" ] && echo "signed with certificate $IDENTITY" || echo "signed ad-hoc: permissions reset on every build"
echo "$APP"
