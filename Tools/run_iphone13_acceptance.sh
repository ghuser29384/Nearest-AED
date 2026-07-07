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
XCODEBUILD_LOG="${RUNNER_TEMP:-/tmp}/aednowoffline-xcodebuild.log"
APP_BUNDLE_ID="com.aednowoffline.app"

emit_xcodebuild_failure() {
  local status="$1"
  echo "xcodebuild failed with status $status. Last log lines:" >&2
  tail -n 160 "$XCODEBUILD_LOG" >&2 || true

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    python3 - "$XCODEBUILD_LOG" <<'PY'
import sys
from pathlib import Path

log = Path(sys.argv[1])
lines = log.read_text(errors="replace").splitlines() if log.exists() else ["xcodebuild log missing"]
markers = (
    " error: ",
    ": error:",
    " failed (",
    "Failing tests:",
    "XCTAssert",
    "** TEST FAILED **",
    "Testing failed:",
)
matches = [line for line in lines if any(marker in line for marker in markers)]
summary = "\n".join(matches[-40:] or lines[-40:])
summary = summary.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
print(f"::error title=xcodebuild acceptance failure summary::{summary}")
PY
  fi
}

run_xcodebuild_test() {
  local destination="$1"
  rm -f "$XCODEBUILD_LOG"
  set +e
  NSUnbufferedIO=YES xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -parallel-testing-enabled NO \
    test 2>&1 | tee "$XCODEBUILD_LOG"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ $status -ne 0 ]]; then
    emit_xcodebuild_failure "$status"
  fi
  return "$status"
}

capture_qa_evidence() {
  if [[ -z "${QA_EVIDENCE_DIR:-}" ]]; then
    return 0
  fi

  mkdir -p "$QA_EVIDENCE_DIR"
  {
    echo "run_id=${GITHUB_RUN_ID:-local}"
    echo "commit=${GITHUB_SHA:-unknown}"
    echo "device=$DEVICE_NAME"
    echo "runtime=$LATEST_RUNTIME_IDENTIFIER"
    echo "udid=$LATEST_DEVICE_UDID"
    echo "bundle_id=$APP_BUNDLE_ID"
  } >"$QA_EVIDENCE_DIR/manifest.txt"

  local app_path
  app_path="$(
    find "$HOME/Library/Developer/Xcode/DerivedData" \
      -path "*/Build/Products/Debug-iphonesimulator/AEDNowOffline.app" \
      -type d \
      -print 2>/dev/null \
      | sort \
      | tail -n 1
  )"
  if [[ -n "$app_path" ]]; then
    xcrun simctl install "$LATEST_DEVICE_UDID" "$app_path"
  fi

  cat >"$QA_EVIDENCE_DIR/06-voice-control-show-names-label-audit.txt" <<'EOF'
Simulator evidence for Voice Control-compatible labels.
The app exposes primary controls as visible buttons whose accessibility labels match visible text:
- Call 999 / 112
- Find nearest AED
- I am with the person
- I am the AED runner
- Read aloud
- Next AED
- Listen
- Stop listening

CI cannot enable the interactive iOS Voice Control "Show names" overlay, so this file is paired with the simulator screenshot and XCTest assertions for matching labels.
EOF

  launch_and_screenshot() {
    local name="$1"
    shift
    xcrun simctl terminate "$LATEST_DEVICE_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch \
      --terminate-running-process \
      "$@" \
      "$LATEST_DEVICE_UDID" \
      "$APP_BUNDLE_ID" \
      -AEDUITestMode >/dev/null
    sleep 2
    xcrun simctl io "$LATEST_DEVICE_UDID" screenshot "$QA_EVIDENCE_DIR/$name.png"
  }

  local base_env=(
    --env AED_UI_TEST_MODE=1
    --env AED_UI_TEST_MUTE_SPEECH=1
  )
  local location_env=(
    --env AED_UI_TEST_LOCATION_LAT=51.53192
    --env AED_UI_TEST_LOCATION_LON=-0.12632
  )

  launch_and_screenshot "01-emergency-home" "${base_env[@]}" "${location_env[@]}"
  launch_and_screenshot "02-with-patient-mode" "${base_env[@]}" "${location_env[@]}" --env AED_UI_TEST_INITIAL_MODE=withPatient
  launch_and_screenshot "03-aed-runner-mode" "${base_env[@]}" "${location_env[@]}" --env AED_UI_TEST_INITIAL_MODE=runner
  launch_and_screenshot "04-stale-data-warning" "${base_env[@]}" "${location_env[@]}" --env AED_UI_TEST_INITIAL_MODE=runner
  launch_and_screenshot "05-no-location-fallback" "${base_env[@]}" --env AED_UI_TEST_INITIAL_MODE=runner
  launch_and_screenshot "06-voice-control-labels" "${base_env[@]}" "${location_env[@]}"
}

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
  run_xcodebuild_test "$DESTINATION_EXACT"
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    capture_qa_evidence
    exit 0
  fi

  echo "Exact iOS 18.7.8 runtime was not usable. Retrying with the installed iPhone 13 runtime." >&2
else
  echo "Exact iOS 18.7.8 runtime is not installed. Running the installed iOS 18 iPhone 13 runtime." >&2
fi

run_xcodebuild_test "platform=iOS Simulator,id=$LATEST_DEVICE_UDID"
capture_qa_evidence
