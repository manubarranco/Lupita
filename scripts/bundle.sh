#!/bin/sh
# Builds build/Lupita.app (menu bar app). No Xcode needed.
# Signing: macOS keeps the Accessibility and Screen Recording permissions only while the app is
# signed with the same certificate. The script uses, in order: the "Lupita" release certificate
# (Manu's keychain only, D50: releases and Manu's builds share it), then a self-signed
# "Lupita Dev" code-signing certificate (contributors; "Refs Dev" is its old name). Without one,
# it stops. Override with LUPITA_SIGN_IDENTITY; LUPITA_SIGN_IDENTITY=- signs ad-hoc on purpose.
set -e
cd "$(dirname "$0")/.."
# Check the signature first, so a failed check leaves the current build/Lupita.app untouched.
IDENTITIES="$(security find-identity -p codesigning)"
FOUND="$(echo "$IDENTITIES" | grep '"Lupita"' | head -1 | awk '{print $2}')"
[ -z "$FOUND" ] && FOUND="$(echo "$IDENTITIES" | grep -iE '"(Lupita|Refs) Dev"' | head -1 | awk '{print $2}')"
IDENTITY="${LUPITA_SIGN_IDENTITY:-$FOUND}"
if [ -z "$IDENTITY" ]; then
  echo "error: no \"Lupita Dev\" code-signing certificate found, so this build would be signed ad-hoc" >&2
  echo "and macOS would ask for the permissions again. Create the certificate (see README)," >&2
  echo "or, if the keychain is hidden (a sandbox), run outside it." >&2
  echo "To sign ad-hoc on purpose: LUPITA_SIGN_IDENTITY=- $0" >&2
  exit 1
fi
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
  <key>CFBundleShortVersionString</key><string>0.8.0</string>
  <key>CFBundleVersion</key><string>9</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "$IDENTITY" "$APP"
[ "$IDENTITY" = "-" ] && echo "signed ad-hoc on purpose: permissions reset on every build" || echo "signed with certificate $IDENTITY"
echo "$APP"
