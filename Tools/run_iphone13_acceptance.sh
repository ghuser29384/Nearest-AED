#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/AEDNowOffline.xcodeproj"
SCHEME="AEDNowOffline"
DEVICE_NAME="iPhone 13"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-13"
DESTINATION_EXACT="platform=iOS Simulator,name=iPhone 13,OS=18.7.8"
DESTINATION_LATEST="platform=iOS Simulator,name=iPhone 13"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Install/select Xcode with the iOS 18 simulator runtime." >&2
  exit 1
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild cannot run with the selected developer directory: ${DEVELOPER_DIR:-unknown}" >&2
  echo "Select full Xcode, for example: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if ! xcrun --find simctl >/dev/null 2>&1; then
  echo "simctl is not available with the selected developer directory: ${DEVELOPER_DIR:-unknown}" >&2
  echo "Install/select full Xcode with an iOS 18 iPhone 13 simulator runtime." >&2
  exit 1
fi

if ! xcrun simctl list devices available | grep -q "$DEVICE_NAME"; then
  if ! xcrun simctl list devicetypes | grep -q "$DEVICE_TYPE"; then
    echo "iPhone 13 simulator device type is not available in the selected Xcode." >&2
    exit 1
  fi

  RUNTIME_IDENTIFIER="$(
    xcrun simctl list runtimes available \
      | awk '/iOS 18/ { runtime = $NF } END { print runtime }'
  )"
  if [[ -z "$RUNTIME_IDENTIFIER" ]]; then
    echo "No available iOS 18 simulator runtime found. Install an iOS 18 runtime in Xcode." >&2
    exit 1
  fi

  xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME_IDENTIFIER" >/dev/null
fi

if ! xcrun simctl list devices available | grep -q "$DEVICE_NAME"; then
  echo "No available iPhone 13 simulator found or creatable with the installed iOS 18 runtime." >&2
  exit 1
fi

set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION_EXACT" \
  test
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Exact iOS 18.7.8 runtime was not usable. Retrying with the installed iPhone 13 runtime." >&2
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_LATEST" \
    test
fi
