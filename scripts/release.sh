#!/bin/sh
# Builds build/Lupita.zip for a GitHub release, signed with the "Lupita" release certificate (D50).
# Every release must carry the same certificate: it is what lets "Install and restart" replace the
# app and lets macOS keep the user's permissions. The script refuses any other signature.
# The certificate lives only in Manu's login keychain (back it up exported with a password).
set -e
cd "$(dirname "$0")/.."
LEAF='640882e1be97dfaaf9febcce9e3b2277a404fda8'
HASH="$(security find-identity -p codesigning | grep '"Lupita"' | head -1 | awk '{print $2}')"
if [ -z "$HASH" ]; then
  echo "error: the \"Lupita\" release certificate is not in this keychain. Releases are built on Manu's Mac." >&2
  exit 1
fi
LUPITA_SIGN_IDENTITY="$HASH" ./scripts/bundle.sh
if ! codesign -d -r- build/Lupita.app 2>&1 | grep -q "certificate leaf = H\"$LEAF\""; then
  echo "error: build/Lupita.app is not signed with the release certificate" >&2
  exit 1
fi
codesign --verify --strict build/Lupita.app
rm -f build/Lupita.zip
ditto -c -k --keepParent build/Lupita.app build/Lupita.zip
echo "build/Lupita.zip ($(defaults read "$PWD/build/Lupita.app/Contents/Info" CFBundleShortVersionString))"
