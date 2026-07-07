# AED Now Offline

Native SwiftUI iPhone app for finding nearby AEDs from a bundled offline SQLite database. This repository is configured for personal use first on:

- iPhone 13, 6.1-inch display
- iOS 18.7.8 runtime assumption
- Minimum deployment target: iOS 18.0

The app does not require internet in emergency mode and does not require Apple Intelligence, Camera Control, Action Button, satellite emergency features, Apple Watch, analytics, ads, accounts, online maps, online routing, cloud speech recognition, OpenAI APIs, or remote AED APIs.

## Safety Limits

This app is only an aid. The first visible and spoken emergency instruction is:

> Call 999 or 112 now. If someone is unresponsive and not breathing normally, start CPR. If you are alone with the person, do not leave them unless instructed by emergency services. Send someone else for the AED if possible.

AED data may be incomplete, outdated, inaccessible, or wrong. In an emergency, call 999/112. Dispatchers may have more current AED information.

## Project Contents

- `AEDNowOffline/AEDNowOfflineApp.swift` wires the emergency model and launch flow.
- `EmergencyHomeView.swift`, `WithPatientView.swift`, `RunnerModeView.swift`, and `AEDCardView.swift` implement the large-button iPhone UI.
- `LocationManager.swift` and `HeadingManager.swift` use CoreLocation for position and compass heading.
- `AEDDatabase.swift`, `AEDRepository.swift`, `AEDSearchService.swift`, and `DistanceBearing.swift` implement offline SQLite lookup, bounding-box prefiltering, Haversine distance, bearing, and ranking.
- `VoiceCommandManager.swift` uses Apple Speech with `requiresOnDeviceRecognition = true` when available.
- `SpeechOutputService.swift` uses `AVSpeechSynthesizer`.
- `AppIntents/AEDAppIntents.swift` exposes Shortcuts/Siri actions.
- `Tools/import_aeds.py` imports permitted CSV, JSON, or GeoJSON AED data into SQLite.
- `AEDNowOffline/Resources/aed_seed.sqlite` is a bundled synthetic seed database with 100,006 records for offline performance testing.
- Emergency screens show source reliability and age warnings from bundled database metadata. The app does not expose runtime data-update actions.

## Data

The bundled database is synthetic development data. It is not a real AED coverage dataset and should not be used as field truth. Import a permitted real source before relying on the app outside development.

Do not use restricted datasets without written permission. For UK data, do not assume The Circuit/BHF data can be used in an app without permission. The importer supports OpenStreetMap-style `emergency=defibrillator` records, but you must comply with source licensing and attribution.

Import example:

```bash
python3 Tools/import_aeds.py path/to/aeds.geojson \
  --output AEDNowOffline/Resources/aed_seed.sqlite \
  --dataset-id "permitted-aed-source" \
  --region-id "london" \
  --version "2026.07.07" \
  --source "Permitted AED source name" \
  --attribution "Required attribution text" \
  --licence "Permitted redistribution licence" \
  --reliability medium
```

Private cabinet codes are not exposed unless the input explicitly marks the code public/permitted. Locked cabinets otherwise show: `Call emergency services for code`.

## Emergency Launcher On iPhone 13

iPhone 13 has no Action Button, so use these launcher paths:

- Siri/App Shortcut phrase: `Find nearest AED in AED Now Offline`.
- Shortcuts action: `Find Nearest AED` opens Runner Mode.
- Home Screen shortcut: in Shortcuts, create a shortcut using `Find Nearest AED`, then use Share > Add to Home Screen.
- Control Center: on iOS 18, add a Shortcut control if available, then choose the `Find Nearest AED` shortcut.
- Back Tap: Settings > Accessibility > Touch > Back Tap, choose Double Tap or Triple Tap, then assign the `Find Nearest AED` shortcut.
- Lock Screen: use the Shortcuts Lock Screen widget if available and point it at the `Find Nearest AED` shortcut.

## Voice And Accessibility

There are two parallel control paths:

1. In-app voice commands using Apple Speech with on-device recognition only where supported.
2. iOS Voice Control-compatible large buttons, visible text, accessibility labels, and accessibility input labels.

Required command examples include `nearest AED`, `find AED`, `show defibrillator`, `next AED`, `previous AED`, `read aloud`, `repeat`, `call emergency`, `runner mode`, `I am with the person`, `bigger text`, and `stop listening`.

If on-device speech recognition is unavailable for the user locale, the app shows a fallback message and remains operable by iOS Voice Control, large buttons, Siri/App Shortcuts where available, and manual touch.

## Offline Test Checklist

Run on an iPhone 13 simulator and, if available, a physical iPhone 13 running iOS 18.7.8:

1. Grant location, speech, and microphone permissions.
2. Put the device in Airplane Mode.
3. Open the app. The emergency home screen should appear without internet.
4. Verify location lookup starts immediately.
5. If a fresh GPS fix is unavailable, verify last known location is shown as stale; otherwise verify the AED list fallback appears.
6. Tap `Find nearest AED`; Runner Mode should show a compass arrow or textual direction, distance in metres, address/location details, access status, `Read aloud`, and `Next AED`.
7. If on-device speech recognition is supported, say `nearest AED`; Runner Mode should open and read the nearest AED.
8. If on-device speech recognition is not supported, verify the fallback message and operate the app with Voice Control using visible labels.
9. Run the `Find Nearest AED` App Shortcut; it should open Runner Mode.
10. Confirm no Action Button, Apple Intelligence, satellite emergency, Apple Watch, online maps, or online routing feature is required.
11. Test largest Dynamic Type on the iPhone 13 6.1-inch screen.
12. Confirm local AED lookup with the 100,000-record database completes within 2 seconds on iPhone 13-class hardware.

## Network Audit

Emergency Mode is fully offline. Update AED data before use by running `Tools/import_aeds.py` with a permitted source and bundling the resulting SQLite database. The app does not perform runtime update checks, background refresh, remote downloads, or AED data installation.

Run this local check for the bundled database and compiled app-target invariants:

```bash
python3 Tools/verify_offline_db.py
```

This verifies the bundled database has at least 100,000 records, latitude/longitude indexes, no network or background-update APIs in app Swift files, no background-update plist keys, deployment target `18.0`, iPhone-only device family, app target source references, the iPhone 13 UI-test target wiring, required safety copy, App Shortcut launcher coverage, launch-time emergency mode behavior, exact offline-only file contracts, and a local nearest-AED query under 2 seconds on the current machine.

For all non-Xcode checks available on a Command Line Tools-only machine:

```bash
Tools/validate_local.sh
```

## Build And Test

Open `AEDNowOffline.xcodeproj` in Xcode on a machine with the iOS 18 SDK. Select the shared `AEDNowOffline` scheme and an iPhone 13 simulator. Build and run tests with:

```bash
xcodebuild -project AEDNowOffline.xcodeproj \
  -scheme AEDNowOffline \
  -destination 'platform=iOS Simulator,name=iPhone 13,OS=18.7.8' \
  test
```

If that exact simulator runtime is not installed, use the closest iOS 18 iPhone 13 simulator and repeat on physical hardware if possible.

If `xcode-select -p` prints `/Library/Developer/CommandLineTools`, select full Xcode first, for example:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Or run:

```bash
Tools/run_iphone13_acceptance.sh
```

The shared scheme includes:

- `AEDNowOfflineTests` for distance, bearing, sorting, stale-location, metadata, importer policy, voice parsing, iPhone 13 target contracts, and 100,000-record lookup checks.
- `AEDNowOfflineUITests` for iPhone 13 acceptance flows using deterministic launch-time fixtures: primary controls, cold launch first-control timing, offline runner flow, stale location, largest Dynamic Type, speech fallback, simulated voice command routing, shortcut-equivalent runner launch, and emergency call confirmation.

UI-test launch hooks are active only when `AED_UI_TEST_MODE=1` or `-AEDUITestMode` is present. Supported hooks:

- `AED_UI_TEST_INITIAL_MODE=runner`
- `AED_UI_TEST_LOCATION_LAT=51.53192`
- `AED_UI_TEST_LOCATION_LON=-0.12632`
- `AED_UI_TEST_STALE_LOCATION=1`
- `AED_UI_TEST_AIRPLANE_MODE_EQUIVALENT=1`
- `AED_UI_TEST_FORCE_SPEECH_UNAVAILABLE=1`
- `AED_UI_TEST_SIMULATED_VOICE_COMMAND=nearestAED`
- `AED_UI_TEST_MUTE_SPEECH=1`
