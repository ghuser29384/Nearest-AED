# AED Now Offline Safety QA Audit

Audit date: 2026-07-07  
Audited commit: `2a47d93`  
Target: iPhone 13, iOS 18 runtime, offline emergency use, personal-use prototype only.  
Primary CI evidence: GitHub Actions run `28859484004`, job `85594216135`, artifact `iphone13-qa-evidence` (`8135174679`, 2.8 MB). The artifact contains `QA_Evidence/iPhone13/iphone13-acceptance.xcresult` with screenshot and accessibility attachments.

## Executive Verdict

The app passes the current automated iPhone 13 acceptance suite and has no app-level network request APIs in Emergency Mode. It is not safe for real emergency reliance because the bundled AED database is synthetic development data. The update-pack/signature requirement is not implemented; the current design instead removes runtime updates entirely and relies on an external importer.

## Critical Defects

| ID | Defect | Evidence | Risk | Suggested patch |
|---|---|---|---|---|
| C1 | No real permitted AED dataset is bundled. The only bundled AED database is synthetic development/performance data. | `AEDNowOffline/Resources/aed_seed.sqlite` metadata: `source=Synthetic permitted development seed`, `record_count=100006`, `reliability=unknown`; README warns it is not field truth. | A user could see plausible nearest-AED UI for non-existent AEDs. | Do not distribute as emergency-capable until a permitted real dataset is imported. Add a production build gate that fails if metadata source contains `Synthetic` or reliability is `unknown`. Patch `Tools/verify_offline_db.py::check_database`, `AEDNowOffline/AEDSourceMetadata.warnings`, and README release instructions. |

## High-Risk Defects

| ID | Defect | Evidence | Risk | Suggested patch |
|---|---|---|---|---|
| H1 | Update-pack signature/hash verification is absent. | No `AEDDataPack`, manifest, signature, hash, or update-pack install code exists; `Tools/verify_offline_db.py` forbids those stale symbols. `Tools/import_aeds.py` imports local files but does not sign or verify update packs. | If manual/runtime updates are later added without cryptographic verification, tampered AED data could be installed. | Implement an offline data-pack format with manifest SHA-256 and Ed25519 signature verification before DB swap. Patch new `AEDDataPackVerifier`, `AEDDataUpdateService`, and tests under `AEDNowOfflineTests`. |
| H2 | Manual update is developer-tool-only, not an in-app/manual user workflow, and failed app-level DB update rollback is not implemented. | README points to `Tools/import_aeds.py`; app has no update UI/service; `AEDDatabase.writeMetadata` can mutate DB metadata but there is no atomic installed/previous DB swap. | Users cannot safely refresh data in-app; future failed update work could corrupt the only DB unless designed atomically. | Add a manual "Install data pack" flow outside Emergency Mode, store packs in Application Support, verify then atomically replace a symlink/current DB pointer, keeping previous DB intact. |
| H3 | The hard-required data warning is semantically present but not exact: required text says "In an emergency, call 999 or 112. AED data may be incomplete..." while app says "AED data may be incomplete... In an emergency, call 999/112." | `AEDNowOffline/AppRouting.swift::EmergencyCopy.dataWarning`. | Safety copy may not satisfy exact regulatory/product requirement. | Change copy to exactly: "In an emergency, call 999 or 112. AED data may be incomplete, outdated, inaccessible, or wrong." Keep dispatcher sentence after it. |

## Medium-Risk Defects

| ID | Defect | Evidence | Risk | Suggested patch |
|---|---|---|---|---|
| M1 | CI tests an Airplane Mode equivalent, not actual simulator network disablement or physical Airplane Mode. | `testAirplaneModeEquivalentOfflineRunnerFlowUsesLocalData` only uses test fixtures and does not toggle radios. | A platform permission/GPS edge case could be missed. | Add physical iPhone 13 Airplane Mode test and, if possible, CI simulator network conditioning. |
| M2 | CI cannot enable the interactive iOS Voice Control "Show names" overlay. | Evidence artifact includes screenshots, accessibility hierarchy, and label assertions, but not a real Voice Control overlay. | Voice Control behavior is inferred from accessibility labels, not fully exercised. | Add manual Voice Control test on physical iPhone 13 using "Show names", "Tap Call 999 / 112", "Tap Read aloud", and "Tap Next AED". |
| M3 | No physical iPhone 13 test has been executed. | CI evidence is simulator-only. | GPS, compass, speech locale, and telephony prompts differ on device. | Run the physical-device plan below before any emergency reliance. |
| M4 | Bundled synthetic DB lacks per-record `licence_text` and metadata `licence`, though production importer creates those fields. | SQLite schema for bundled DB has no `licence_text`; metadata has no `licence`. | Data provenance display is weaker for the bundled DB. | Regenerate synthetic seed through current `Tools/import_aeds.py` with explicit licence metadata, or fail production builds when licence metadata is missing. |

## Low-Risk Defects

| ID | Defect | Evidence | Risk | Suggested patch |
|---|---|---|---|---|
| L1 | GitHub artifact download requires authentication; unauthenticated API returns 401. | Artifact listing works, zip download does not without auth. | External reviewers without repo/session access cannot inspect screenshots. | For public review, publish sanitized QA screenshots in a release asset or committed `QA_Evidence/README.md` with exported images. |

## Acceptance Test Results

Evidence: passing run `28859484004` on `macos-15`, Xcode-selected runner, iPhone 13 simulator on installed iOS 18 runtime.

| Acceptance test | Result | Evidence |
|---|---:|---|
| Emergency home shows iPhone 13 primary controls | PASS | `testEmergencyHomeShowsIPhone13PrimaryControls`; screenshot `01-emergency-home.png` attachment |
| Cold launch shows emergency home first control within 1 second where possible | PASS | `testColdLaunchShowsEmergencyHomeWithinOneSecondWherePossible` |
| Runner mode shows nearest AED and Next AED | PASS | `testRunnerModeShowsNearestAEDAndNextAED`; screenshot `03-aed-runner-mode.png` |
| With-patient mode shows safety controls | PASS | `testWithPatientModeShowsSafetyControls`; screenshot `02-with-patient-mode.png` |
| Airplane Mode equivalent uses local data | PASS with limitation | `testAirplaneModeEquivalentOfflineRunnerFlowUsesLocalData`; actual Airplane Mode remains manual |
| Stale location is clearly marked | PASS | `testStaleLocationIsClearlyMarked` |
| Stale AED data warning is visible | PASS | `testStaleAEDDataWarningIsVisible`; screenshot `04-stale-data-warning.png` |
| No-location fallback shows bundled list/search | PASS | `testNoLocationFallbackShowsBundledList`; screenshot `05-no-location-fallback.png` |
| Largest Dynamic Type still shows primary controls on iPhone 13 | PASS | `testLargestDynamicTypeStillShowsPrimaryControlsOnIPhone13` |
| Speech unavailable falls back to Voice Control-compatible buttons | PASS | `testSpeechUnavailableFallsBackToVoiceControlCompatibleButtons` |
| Voice Control labels match visible primary text | PASS with limitation | `testVoiceControlLabelsMatchVisiblePrimaryText`; screenshot `06-voice-control-labels.png`; no live Show Names overlay |
| Simulated "nearest AED" voice command opens Runner Mode | PASS | `testSimulatedNearestAEDVoiceCommandOpensRunnerMode` |
| Shortcut-equivalent runner launch opens Runner Mode | PASS | `testFindNearestAEDShortcutEquivalentOpensRunnerMode` |
| Emergency call confirmation opens without placing call | PASS | `testCall999112OpensConfirmationWithoutPlacingCall` |

## Network Call Audit

| Surface | Code | Can occur in Emergency Mode? | Network request? | Finding |
|---|---|---:|---:|---|
| HTTP/network APIs | Static scan in `Tools/verify_offline_db.py::check_network_bounds` forbids `URLSession`, `http://`, `https://`, `MKMapView`, `MKDirections`, `CLGeocoder` in app Swift files. | No app code found | No | PASS |
| Background networking | Static scan forbids `BackgroundTasks`, `BGTaskScheduler`, background URL-session/update symbols; Info.plist scan forbids background modes. | No | No | PASS |
| Emergency call prompt | `AEDNowOffline/EmergencyCallService.swift::openCallPrompt` opens `tel://999`. | Only after confirmation dialog | Not an app network request | PASS; external telephony action |
| CoreLocation | `LocationManager.requestWhenInUsePermission`, `requestOneShotLocation`, heading updates. | Yes | No app network request | PASS; GPS/OS location only |
| Speech | `VoiceCommandManager` requires on-device recognition when supported. | Only when Listen tapped | No app network request by app; audio not sent by app | PASS with OS-service caveat |
| AVSpeechSynthesizer | `SpeechOutputService.speak`. | Yes | No | PASS |

## Data Source And Licence Audit

| Data source | Location | Licence/attribution | Legal bundle/use status |
|---|---|---|---|
| Synthetic permitted development seed | `AEDNowOffline/Resources/aed_seed.sqlite` | Attribution metadata: "Synthetic AED records for development and offline performance testing; replace with permitted production AED data before field use." No DB licence key. | Allowed only as project-owned synthetic development/test data; not allowed as real emergency AED truth. |
| UI test source | `AEDNowOffline/UITestFixtures.swift` | "Synthetic UI test data"; no licence field. | Test-only synthetic data; acceptable for simulator fixtures. |
| User-provided CSV/JSON/GeoJSON imports | `Tools/import_aeds.py` | Requires `--source`, `--attribution`, `--licence`, dataset ID, region ID, version. | Allowed only if the supplied source licence permits app/database redistribution. |
| OpenStreetMap-style AED records | Importer policy comments | Must preserve ODbL attribution/share-alike. | Potentially allowed if ODbL obligations are followed; no OSM data is currently bundled. |
| UK The Circuit/BHF | Importer policy comments and README | Explicit written consent required. | Not bundled; do not use without permission. |

## Code-Level Safety Report

| Requirement | Current status | Evidence |
|---|---|---|
| Prevents Emergency Mode network calls | PASS by absence/static gate | `Tools/verify_offline_db.py` network patterns and forbidden app patterns; no app `URLSession`/map/routing/geocoder APIs found. |
| Verifies update-pack signatures/hashes | FAIL | No update-pack verifier exists. Only local row ID hashing in `Tools/import_aeds.py::stable_id` and source-file contract hashes in `Tools/verify_offline_db.py`. |
| Marks stale location | PASS | `LocationManager.applyTestingLocation` and `updateLocation`; `AEDAppModel.refreshNearest` sets "Location may be outdated." |
| Marks stale AED data | PASS | `AEDSourceMetadata.warnings`; `EmergencyHomeView`, `WithPatientView`, `RunnerModeView` render `dataSourceWarnings`. |
| Prevents private cabinet codes | PASS for importer/default seed | `Tools/import_aeds.py::cabinet_instruction` exposes literal code only if public/permitted; verifier checks no synthetic `Cabinet code:` rows. |
| Prioritizes emergency call/CPR first | PASS | `EmergencyCopy.primaryInstruction`, first banner in all modes, startup speech, selected-AED readout repeats primary instruction. |
| Large visible controls with matching labels | PASS in tested controls | Buttons set visible labels plus matching `accessibilityLabel`/`accessibilityInputLabels`; UI test asserts primary labels. |
| On-device speech fallback | PASS | `VoiceCommandManager` rejects unsupported on-device recognition and reports "Use buttons or iOS Voice Control"; UI test covers forced unavailable state. |

## Screenshot / Simulator Evidence

The passing artifact `iphone13-qa-evidence` contains an `.xcresult` bundle with kept XCTest attachments:

| Required evidence | Attachment |
|---|---|
| Emergency home screen | `01-emergency-home.png`, `01-emergency-home-accessibility.txt` |
| With-patient mode | `02-with-patient-mode.png`, `02-with-patient-mode-accessibility.txt` |
| AED-runner mode | `03-aed-runner-mode.png`, `03-aed-runner-mode-accessibility.txt` |
| Stale data warning | `04-stale-data-warning.png`, `04-stale-data-warning-accessibility.txt` |
| No-location fallback | `05-no-location-fallback.png`, `05-no-location-fallback-accessibility.txt` |
| Voice Control labels / Show names equivalent | `06-voice-control-labels.png`, `06-voice-control-labels-accessibility.txt`, `06-voice-control-show-names-label-audit.txt` |

Limitation: CI cannot enable the live iOS Voice Control "Show names" overlay. The evidence proves visible/accessibility label matching, not the actual system overlay.

## Physical iPhone 13 Test Plan

1. Install a build containing a permitted real AED database; verify metadata source, licence, attribution, source date, record count, and reliability.
2. Grant When In Use location, microphone, and speech permissions.
3. Turn on Airplane Mode. Confirm Wi-Fi and cellular are disabled.
4. Cold-launch the app. Confirm the first visible and spoken instruction is to call emergency services and start CPR.
5. Tap `Find nearest AED`. Confirm nearest list appears from local DB within 2 seconds.
6. Confirm no network indicators, online map, geocoder, routing, or data-update UI appears in Emergency Mode.
7. Move to stale/no-GPS conditions if possible; confirm stale location or no-location fallback appears.
8. Enable largest Dynamic Type and high contrast; repeat home, with-patient, and runner flows.
9. Enable Voice Control, say "Show names", then "Tap Call 999 / 112", "Tap Find nearest AED", "Tap Read aloud", "Tap Next AED", and "Tap Stop listening".
10. Test on-device speech unavailable path by denying speech/mic permissions and confirming buttons remain usable.
11. Confirm emergency call confirmation appears and no call is placed until explicit confirmation.
12. If update packs are implemented later, install a valid pack, reject a tampered pack, and confirm failed installs preserve the previous working DB.

## Suggested Patches By File/Function

| Priority | File/function | Patch |
|---|---|---|
| Critical | `Tools/verify_offline_db.py::check_database` | Add production mode that fails if bundled DB source contains `Synthetic`, `record_count` is synthetic-only, licence is missing, or reliability is `unknown`. |
| Critical | `AEDNowOffline/AEDRepository.swift::AEDSourceMetadata.warnings` | Make synthetic/no-real-data warning unmissable and consider disabling runner mode in production builds without permitted data. |
| High | New `AEDDataPackVerifier` | Verify manifest SHA-256 for every DB and Ed25519 signature before any install. |
| High | New `AEDDataUpdateService` | Implement non-emergency manual data-pack install with atomic swap and previous DB retention. |
| High | `AEDNowOffline/AppRouting.swift::EmergencyCopy.dataWarning` | Change to exact required wording: "In an emergency, call 999 or 112. AED data may be incomplete, outdated, inaccessible, or wrong." |
| Medium | `.github/workflows/iphone13-acceptance.yml` / UI tests | Add explicit artifact export documentation and optionally publish sanitized screenshots for reviewers without GitHub auth. |
| Medium | Physical QA procedure | Run the physical-device plan before any real use; record device model, iOS build, Airplane Mode state, and screenshots. |

