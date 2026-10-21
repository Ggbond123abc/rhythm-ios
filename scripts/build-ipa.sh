#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build

xcodebuild \
  -project Rhythm.xcodeproj \
  -scheme Rhythm \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="build/DerivedData/Build/Products/Release-iphoneos/Rhythm.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Build product not found: $APP_PATH" >&2
  exit 1
fi

rm -rf build/Payload
mkdir -p build/Payload
cp -R "$APP_PATH" build/Payload/
cd build
rm -f Rhythm-unsigned.ipa
zip -qry Rhythm-unsigned.ipa Payload
echo "Built: $ROOT/build/Rhythm-unsigned.ipa"
