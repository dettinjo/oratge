#!/usr/bin/env bash
# Builds the Android APK connected to the Oratge backend (token from Infisical).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=$HOME/development/flutter/bin:$PATH ANDROID_HOME=$HOME/Android/Sdk JAVA_HOME=$HOME/development/jdk21
API=${ORATGE_API:-http://100.96.0.121:8199}
TOKEN=$(infisical-get ORATGE_API_TOKEN)
flutter build apk --release --split-per-abi --dart-define=ORATGE_API="$API" --dart-define=ORATGE_TOKEN="$TOKEN"
ls -la build/app/outputs/flutter-apk/
