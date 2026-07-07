#!/usr/bin/env python3
"""Local verification for AED Now Offline on hosts without full Xcode."""

from __future__ import annotations

import hashlib
import math
import re
import sqlite3
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "AEDNowOffline"
PROJECT_FILE = ROOT / "AEDNowOffline.xcodeproj" / "project.pbxproj"
INFO_PLIST = APP_DIR / "Info.plist"
DATABASE = APP_DIR / "Resources" / "aed_seed.sqlite"
README = ROOT / "README.md"
APP_SOURCE_MANIFEST = ROOT / "Tools" / "app_source_manifest.txt"
OFFLINE_CONTRACT_SHA256 = {
    "AEDNowOffline/AEDRepository.swift": "124b31e2b9b7f2591ec74e5e5b4d06c62d183001a33caabadfff2ae982c5b11b",
    "AEDNowOffline/AEDNowOfflineApp.swift": "8117a3705f24203d157f613487a147670e39a8bfb79d8dcab7d7623cea2f1eb2",
    "AEDNowOffline/EmergencyHomeView.swift": "153bc7359c5117075324a5fb2ad3cd877a2008973a5a6d815349db2f2d0a10bb",
    "AEDNowOffline/Info.plist": "80417c92409ab9d63f5f202a5b447828eb462e3bb7ed438bb39e54938cd93572",
}

NETWORK_PATTERNS = ("URLSession", "MKMapView", "CLGeocoder", "MKDirections", "http://", "https://")
PRIMARY_LABELS = (
    "Call 999 / 112",
    "I am with the person",
    "I am the AED runner",
    "Find nearest AED",
    "Read aloud",
    "Next AED",
)
UNSUPPORTED_FEATURE_PATTERNS = (
    "Apple Intelligence",
    "Action Button",
    "Camera Control",
    "Apple Watch",
    "iPhone 14",
    "iPhone 15",
    "iPhone 16",
    "satellite",
)
FORBIDDEN_APP_PATTERNS = (
    "AEDBackgroundUpdateScheduler",
    "AEDDataPack",
    "AEDDataPacksView",
    "AEDDataUpdateController",
    "AEDDataUpdateService",
    "AEDPackStore",
    "AEDUpdateManifest",
    "AEDSignatureVerificationStatus",
    "BackgroundTasks",
    "BGTaskScheduler",
    "checkForDataUpdates",
    "dataUpdateStatusMessage",
    "handleEventsForBackgroundURLSession",
    "hasOfflineDataCovering",
    "installDataPack",
    "removeDataPack",
    "signatureVerificationStatus",
    "showNoOfflineDataForArea",
    "startNormalMode",
    "updateAEDDataNow",
)
FORBIDDEN_INFO_PLIST_PATTERNS = (
    "AEDUpdateManifestURL",
    "BGTaskSchedulerPermittedIdentifiers",
    "UIBackgroundModes",
    "com.aednowoffline.app.aed-data-refresh",
)
FORBIDDEN_README_PATTERNS = (
    "Normal non-emergency use may expose update checks",
    "pack controls",
    "manifest.json plus a full SQLite snapshot",
    "Future JSON deltas",
)
FORBIDDEN_TEST_PATTERNS = (
    "AEDBackgroundUpdateScheduler",
    "AEDDataPack",
    "AEDDataStatusSummary",
    "AEDDataUpdateController",
    "AEDDataUpdateService",
    "AEDPackStore",
    "AEDUpdateManifest",
)
REQUIRED_VOICE_PHRASES = (
    "nearest aed",
    "find aed",
    "show defibrillator",
    "next aed",
    "previous aed",
    "read aloud",
    "repeat",
    "call emergency",
    "runner mode",
    "i am with the person",
    "bigger text",
    "stop listening",
)
ACCEPTANCE_TEST_METHODS = (
    "testEmergencyHomeShowsIPhone13PrimaryControls",
    "testColdLaunchShowsEmergencyHomeWithinOneSecondWherePossible",
    "testRunnerModeShowsNearestAEDAndNextAED",
    "testAirplaneModeEquivalentOfflineRunnerFlowUsesLocalData",
    "testStaleLocationIsClearlyMarked",
    "testLargestDynamicTypeStillShowsPrimaryControlsOnIPhone13",
    "testSpeechUnavailableFallsBackToVoiceControlCompatibleButtons",
    "testSimulatedNearestAEDVoiceCommandOpensRunnerMode",
    "testFindNearestAEDShortcutEquivalentOpensRunnerMode",
    "testCall999112OpensConfirmationWithoutPlacingCall",
)
TARGET_TEST_METHODS = (
    "testEmergencyRegionUsesUKInstructionAndButtonCopy",
    "testNoUnsupportedHardwareFeatureNamesInEmergencyCopy",
    "testVoiceFallbackMessageIsExplicitWhenOnDeviceSpeechUnavailable",
    "testFindNearestAEDAppIntentRoutesToRunnerMode",
    "testIPhone13AcceptanceScriptTargetsExactRuntimeFirst",
    "testLookupOverOneHundredThousandRecordsIsUnderTwoSecondsOnHost",
)


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def check_database() -> None:
    if not DATABASE.exists():
        fail(f"missing database: {DATABASE}")

    connection = sqlite3.connect(DATABASE)
    try:
        count = connection.execute("select count(*) from aed_records").fetchone()[0]
        if count < 100_000:
            fail(f"expected at least 100000 records, found {count}")

        metadata = dict(connection.execute("select key, value from metadata"))
        if metadata.get("source") != "Synthetic permitted development seed":
            fail("unexpected bundled source metadata")
        if metadata.get("reliability") != "unknown":
            fail("bundled seed should preserve unknown reliability warning")

        indexes = {row[1] for row in connection.execute("pragma index_list(aed_records)").fetchall()}
        if "idx_aed_records_lat_lon" not in indexes or "idx_aed_records_lon_lat" not in indexes:
            fail("missing latitude/longitude indexes")

        exposed_codes = connection.execute(
            """
            select count(*) from aed_records
            where cabinet_code_instruction like 'Cabinet code:%'
              and (notes like '%Synthetic%' or source like '%Synthetic%')
            """
        ).fetchone()[0]
        if exposed_codes:
            fail("synthetic seed unexpectedly exposes cabinet codes")
    finally:
        connection.close()


def check_lookup_time() -> None:
    origin = (51.53192, -0.12632)
    radius = 50_000.0
    lat_delta = radius / 111_320.0
    lon_delta = radius / (111_320.0 * max(0.01, math.cos(math.radians(origin[0]))))

    started = time.perf_counter()
    connection = sqlite3.connect(DATABASE)
    try:
        rows = connection.execute(
            """
            select id, latitude, longitude
            from aed_records
            where latitude between ? and ?
              and longitude between ? and ?
            """,
            (origin[0] - lat_delta, origin[0] + lat_delta, origin[1] - lon_delta, origin[1] + lon_delta),
        ).fetchall()
    finally:
        connection.close()

    def distance(row: tuple[object, ...]) -> float:
        latitude = float(row[1])
        longitude = float(row[2])
        dlat = math.radians(latitude - origin[0])
        dlon = math.radians(longitude - origin[1])
        a = (
            math.sin(dlat / 2) ** 2
            + math.cos(math.radians(origin[0]))
            * math.cos(math.radians(latitude))
            * math.sin(dlon / 2) ** 2
        )
        return 6_371_000.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    nearest = sorted((row for row in rows if distance(row) <= radius), key=distance)[:10]
    elapsed = time.perf_counter() - started
    if not nearest:
        fail("nearest AED query returned no records")
    if elapsed >= 2.0:
        fail(f"nearest lookup took {elapsed:.4f}s, expected under 2s")
    print(f"lookup_rows={len(rows)} nearest={len(nearest)} elapsed={elapsed:.4f}s")


def check_app_source_manifest() -> None:
    expected = [
        line.strip()
        for line in APP_SOURCE_MANIFEST.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    actual = sorted(str(path.relative_to(ROOT)) for path in APP_DIR.rglob("*.swift"))
    if actual != expected:
        extra = sorted(set(actual) - set(expected))
        missing = sorted(set(expected) - set(actual))
        details: list[str] = []
        if extra:
            details.append("extra: " + ", ".join(extra))
        if missing:
            details.append("missing: " + ", ".join(missing))
        fail("app source manifest drift; " + "; ".join(details))


def check_update_system_contract() -> None:
    offenders: list[str] = []
    for relative_path, expected_digest in OFFLINE_CONTRACT_SHA256.items():
        path = ROOT / relative_path
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != expected_digest:
            offenders.append(f"{relative_path}: expected {expected_digest}, got {digest}")
    if offenders:
        fail("offline-only file contract drift:\n" + "\n".join(offenders))

    readme = README.read_text(encoding="utf-8")
    forbidden_docs = [pattern for pattern in FORBIDDEN_README_PATTERNS if pattern in readme]
    if forbidden_docs:
        fail("README still documents removed update-pack behavior: " + ", ".join(forbidden_docs))


def check_network_bounds() -> None:
    offenders: list[str] = []
    for path in APP_DIR.rglob("*.swift"):
        source = path.read_text(encoding="utf-8")
        relative = str(path.relative_to(ROOT))
        for pattern in NETWORK_PATTERNS:
            if pattern in source:
                offenders.append(f"{relative}: {pattern}")
        for pattern in FORBIDDEN_APP_PATTERNS:
            if pattern in source:
                offenders.append(f"{relative}: {pattern}")
    if offenders:
        fail("network/update API patterns found in app source:\n" + "\n".join(offenders))


def check_info_plist_update_configuration() -> None:
    text = INFO_PLIST.read_text(encoding="utf-8")
    offenders = [pattern for pattern in FORBIDDEN_INFO_PLIST_PATTERNS if pattern in text]
    if offenders:
        fail("background/update plist configuration found: " + ", ".join(offenders))


def check_device_specific_source_invariants() -> None:
    app_text = "\n".join(path.read_text(encoding="utf-8") for path in APP_DIR.rglob("*.swift"))
    required_safety = (
        "AED data may be incomplete, outdated, inaccessible, or wrong. "
        "In an emergency, call 999/112. Dispatchers may have more current AED information."
    )
    if required_safety not in app_text:
        fail("required AED data safety warning is missing or changed")

    missing_labels = [label for label in PRIMARY_LABELS if label not in app_text]
    if missing_labels:
        fail("missing primary labels: " + ", ".join(missing_labels))

    unsupported = [pattern for pattern in UNSUPPORTED_FEATURE_PATTERNS if pattern.lower() in app_text.lower()]
    if unsupported:
        fail("unsupported newer-device feature references in app source: " + ", ".join(unsupported))

    app_source = (APP_DIR / "AEDNowOfflineApp.swift").read_text(encoding="utf-8")
    required_flow = (
        "func startEmergencyMode()",
        "speechOutputService.speak(EmergencyCopy.primaryInstruction(settings: settings))",
        "locationManager.requestWhenInUsePermission()",
        "locationManager.requestOneShotLocation()",
        "headingManager.start()",
        "refreshNearest()",
        "@StateObject private var intentRouter = AppIntentRouter.shared",
        "model.open(requestedMode)",
        ".onReceive(intentRouter.$requestedMode.compactMap { $0 })",
    )
    missing_flow = [pattern for pattern in required_flow if pattern not in app_source]
    if missing_flow:
        fail("emergency launch/App Intent flow is missing: " + ", ".join(missing_flow))

    intents = (APP_DIR / "AppIntents" / "AEDAppIntents.swift").read_text(encoding="utf-8")
    required_intents = (
        "struct FindNearestAEDIntent",
        "struct OpenRunnerModeIntent",
        "struct OpenWithPatientModeIntent",
        "static let openAppWhenRun = true",
        "AppIntentRouter.shared.request(.runner)",
        "AppIntentRouter.shared.request(.withPatient)",
        '"Find nearest AED in \\(.applicationName)"',
        'shortTitle: "Find nearest AED"',
        "struct AEDAppShortcuts: AppShortcutsProvider",
    )
    missing_intents = [pattern for pattern in required_intents if pattern not in intents]
    if missing_intents:
        fail("App Shortcut launcher coverage is missing: " + ", ".join(missing_intents))

    voice_source = (APP_DIR / "VoiceCommand.swift").read_text(encoding="utf-8").lower()
    voice_tests = (ROOT / "AEDNowOfflineTests" / "VoiceCommandParserTests.swift").read_text(encoding="utf-8").lower()
    missing_voice_source = [phrase for phrase in REQUIRED_VOICE_PHRASES if f'"{phrase}"' not in voice_source]
    missing_voice_tests = [phrase for phrase in REQUIRED_VOICE_PHRASES if f'"{phrase}"' not in voice_tests]
    if missing_voice_source:
        fail("required voice command phrases are missing from VoiceCommand.swift: " + ", ".join(missing_voice_source))
    if missing_voice_tests:
        fail("required voice command phrases are missing from parser tests: " + ", ".join(missing_voice_tests))


def compiled_app_swift_files() -> list[Path]:
    text = PROJECT_FILE.read_text(encoding="utf-8")
    source_phase_match = re.search(
        r"110000000000000000000001 /\* Sources \*/ = \{.*?files = \((.*?)\);",
        text,
        flags=re.S,
    )
    if not source_phase_match:
        fail("could not locate app source build phase")

    names = re.findall(r"/\* ([^*]+\.swift) in Sources \*/", source_phase_match.group(1))
    paths: list[Path] = []
    missing: list[str] = []
    ambiguous: list[str] = []
    for name in names:
        direct = APP_DIR / name
        if direct.exists():
            paths.append(direct)
            continue
        matches = list(APP_DIR.rglob(name))
        if len(matches) == 1:
            paths.append(matches[0])
        elif len(matches) > 1:
            ambiguous.append(name)
        else:
            missing.append(f"AEDNowOffline/{name}")

    if ambiguous:
        fail("app target source names are ambiguous: " + ", ".join(ambiguous))
    if missing:
        fail("app target references missing Swift files: " + ", ".join(missing))
    return paths


def check_deployment_target() -> None:
    text = PROJECT_FILE.read_text(encoding="utf-8")
    targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", text)
    if not targets:
        fail("no iOS deployment target found")
    if any(target != "18.0" for target in targets):
        fail(f"deployment target drift: {targets}")
    targeted_families = re.findall(r"TARGETED_DEVICE_FAMILY = ([0-9,]+);", text)
    if not targeted_families:
        fail("no targeted device family found")
    if any(value != "1" for value in targeted_families):
        fail(f"device family drift; expected iPhone only, got {targeted_families}")

    scheme = ROOT / "AEDNowOffline.xcodeproj" / "xcshareddata" / "xcschemes" / "AEDNowOffline.xcscheme"
    scheme_text = scheme.read_text(encoding="utf-8")
    if "AEDNowOfflineUITests.xctest" not in text or "AEDNowOfflineUITests.xctest" not in scheme_text:
        fail("iPhone 13 UI acceptance test target is not wired into project and scheme")

    script = (ROOT / "Tools" / "run_iphone13_acceptance.sh").read_text(encoding="utf-8")
    required_script = (
        'DESTINATION_EXACT="platform=iOS Simulator,name=iPhone 13,OS=18.7.8"',
        'DESTINATION_LATEST="platform=iOS Simulator,name=iPhone 13"',
        "xcrun --find simctl",
        "xcrun simctl list devices available",
        "xcrun simctl list devicetypes",
        "xcrun simctl list runtimes available",
        "xcrun simctl create",
        "com.apple.CoreSimulator.SimDeviceType.iPhone-13",
        'grep -q "$DEVICE_NAME"',
        '-destination "$DESTINATION_EXACT"',
        '-destination "$DESTINATION_LATEST"',
        "test",
    )
    missing_script = [pattern for pattern in required_script if pattern not in script]
    if missing_script:
        fail("iPhone 13 acceptance script is missing required target behavior: " + ", ".join(missing_script))
    compiled_app_swift_files()


def check_update_test_coverage() -> None:
    target_tests = (ROOT / "AEDNowOfflineTests" / "iPhone13TargetTests.swift").read_text(encoding="utf-8")
    missing_target_tests = [method for method in TARGET_TEST_METHODS if f"func {method}(" not in target_tests]
    if missing_target_tests:
        fail("missing iPhone 13 target tests: " + ", ".join(missing_target_tests))
    missing_unsupported_assertions = [
        pattern.lower()
        for pattern in UNSUPPORTED_FEATURE_PATTERNS
        if f'copy.contains("{pattern.lower()}")' not in target_tests.lower()
    ]
    if missing_unsupported_assertions:
        fail("iPhone 13 target tests do not assert unsupported feature absence: " + ", ".join(missing_unsupported_assertions))

    ui_tests = (ROOT / "AEDNowOfflineUITests" / "AEDNowOfflineDeviceAcceptanceUITests.swift").read_text(encoding="utf-8")
    missing_ui_tests = [method for method in ACCEPTANCE_TEST_METHODS if f"func {method}(" not in ui_tests]
    if missing_ui_tests:
        fail("missing iPhone 13 acceptance tests: " + ", ".join(missing_ui_tests))

    offenders: list[str] = []
    for directory in (ROOT / "AEDNowOfflineTests", ROOT / "AEDNowOfflineUITests"):
        for path in directory.rglob("*.swift"):
            source = path.read_text(encoding="utf-8")
            for pattern in FORBIDDEN_TEST_PATTERNS:
                if pattern in source:
                    offenders.append(f"{path.relative_to(ROOT)}: {pattern}")
    if offenders:
        fail("stale online update-layer test references found:\n" + "\n".join(offenders))


def main() -> None:
    check_database()
    check_lookup_time()
    check_app_source_manifest()
    check_update_system_contract()
    check_network_bounds()
    check_info_plist_update_configuration()
    check_device_specific_source_invariants()
    check_deployment_target()
    check_update_test_coverage()
    print("offline verifier passed")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as error:
        fail(str(error))
