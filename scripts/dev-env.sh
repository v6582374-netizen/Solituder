#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "error: DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
fi

echo "DEVELOPER_DIR=$DEVELOPER_DIR"
"$DEVELOPER_DIR/usr/bin/xcodebuild" -version
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift --version
