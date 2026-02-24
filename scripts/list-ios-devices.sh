#!/usr/bin/env bash
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

echo "Using DEVELOPER_DIR=$DEVELOPER_DIR"
echo

echo "[devicectl] connected physical devices"
xcrun devicectl list devices --hide-default-columns --columns "Identifier,DeviceClass,Name,ConnectionProperties.TunnelState" || true

echo
echo "[xctrace] all detected devices"
xcrun xctrace list devices | sed -n '1,120p'
