#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/AEDNowOffline.xcodeproj"
SCHEME="AEDNowOffline"
DEVICE_NAME="iPhone 13"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-13"
DESTINATION_EXACT="platform=iOS Simulator,name=iPhone 13,OS=18.7.8"
DESTINATION_LATEST="platform=iOS Simulator,name=iPhone 13"
EXACT_RUNTIME_LABEL="iOS 18.7.8"

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

RUNTIMES="$(xcrun simctl list runtimes available)"

if ! xcrun simctl list devicetypes | grep -q "$DEVICE_TYPE"; then
  echo "iPhone 13 simulator device type is not available in the selected Xcode." >&2
  exit 1
fi

LATEST_RUNTIME_IDENTIFIER="$(
  printf "%s\n" "$RUNTIMES" \
    | awk '/iOS 18/ { runtime = $NF } END { print runtime }'
)"
if [[ -z "$LATEST_RUNTIME_IDENTIFIER" ]]; then
  echo "No available iOS 18 simulator runtime found. Install an iOS 18 runtime in Xcode." >&2
  exit 1
fi

device_udid_for_runtime() {
  xcrun simctl list devices available "$1" \
    | python3 -c 'import re, sys
name = sys.argv[1]
for line in sys.stdin:
    if name not in line:
        continue
    match = re.search(r"\(([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})\)", line)
    if match:
        print(match.group(1))
        break' "$DEVICE_NAME"
}

LATEST_DEVICE_UDID="$(device_udid_for_runtime "$LATEST_RUNTIME_IDENTIFIER")"
if [[ -z "$LATEST_DEVICE_UDID" ]]; then
  LATEST_DEVICE_UDID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$LATEST_RUNTIME_IDENTIFIER")"
fi

if ! xcrun simctl list devices available | grep -q "$LATEST_DEVICE_UDID"; then
  echo "No available iPhone 13 simulator found or creatable with the installed iOS 18 runtime." >&2
  exit 1
fi

if printf "%s\n" "$RUNTIMES" | grep -q "$EXACT_RUNTIME_LABEL"; then
  set +e
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_EXACT" \
    test
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    exit 0
  fi

  echo "Exact iOS 18.7.8 runtime was not usable. Retrying with the installed iPhone 13 runtime." >&2
else
  echo "Exact iOS 18.7.8 runtime is not installed. Running the installed iOS 18 iPhone 13 runtime." >&2
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$LATEST_DEVICE_UDID" \
  test
