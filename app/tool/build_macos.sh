#!/usr/bin/env bash
# Builds Oratge.app + Oratge.dmg on a Mac (needs Xcode and Flutter 3.47.x).
# Token: ORATGE_TOKEN env var, or fetched with infisical-get if that's available.
#   ORATGE_TOKEN=… ./tool/build_macos.sh          → app/Oratge.dmg (universal: Apple silicon + Intel)
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname)" == Darwin ]] || { echo "Run this on macOS." >&2; exit 1; }
command -v flutter >/dev/null || { echo "Install Flutter: https://docs.flutter.dev/get-started/install/macos" >&2; exit 1; }
xcodebuild -version >/dev/null 2>&1 || { echo "Install Xcode from the App Store, then: sudo xcodebuild -runFirstLaunch" >&2; exit 1; }
API=${ORATGE_API:-http://100.96.0.121:8199}
TOKEN=${ORATGE_TOKEN:-$(command -v infisical-get >/dev/null && infisical-get ORATGE_API_TOKEN || true)}
[[ -n "$TOKEN" ]] || { echo "Set ORATGE_TOKEN (Infisical: ORATGE_API_TOKEN)." >&2; exit 1; }
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
flutter pub get
flutter build macos --release --build-name="${VERSION%%+*}" --build-number="${VERSION##*+}" \
  --dart-define=ORATGE_API="$API" --dart-define=ORATGE_TOKEN="$TOKEN"
APP=build/macos/Build/Products/Release/Oratge.app
rm -rf dmg Oratge.dmg && mkdir dmg && cp -R "$APP" dmg/ && ln -s /Applications dmg/Applications
hdiutil create -volname Oratge -srcfolder dmg -ov -format UDZO Oratge.dmg >/dev/null && rm -rf dmg
echo "Built $(pwd)/Oratge.dmg ($(lipo -archs "$APP/Contents/MacOS/Oratge"))"
echo "Or copy the app directly: cp -R $APP /Applications/"
