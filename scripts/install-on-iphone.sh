#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Apps/SolituderApp/SolituderApp.xcodeproj"
SCHEME="SolituderApp"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEAM_ID="${TEAM_ID:-}"
DEVICE_UDID="${DEVICE_UDID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.solituder.app.dev}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/DerivedData-iPhone}"

if [[ -z "$TEAM_ID" ]]; then
  echo "error: TEAM_ID is required. Example: TEAM_ID=ABCDE12345" >&2
  exit 1
fi

if [[ -z "$DEVICE_UDID" ]]; then
  echo "error: DEVICE_UDID is required. Run scripts/list-ios-devices.sh to find it." >&2
  exit 1
fi

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "error: DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
fi

export DEVELOPER_DIR

echo "==> Building for iPhone"
echo "    TEAM_ID=$TEAM_ID"
echo "    DEVICE_UDID=$DEVICE_UDID"
echo "    BUNDLE_ID=$BUNDLE_ID"
echo "    DERIVED_DATA_PATH=$DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/Solituder.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Installing app on device"
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

echo "==> Launching app"
xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" --terminate-existing --activate

echo "Done: app installed and launched on iPhone."
