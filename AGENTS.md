# Project guidance for Codex

## Safety-critical authority order

This is a safety-critical emergency-aid prototype. Use this file as durable context, not as evidence that the app is safe for real-world reliance.

For every task, apply this order of authority:

1. The user's current request and any exact safety brief, acceptance copy, named audit, or test requirement.
2. Current repository files, bundled-data provenance, `QA_AUDIT.md`, tests, build artifacts, current device evidence, and current licensing permissions.
3. The project intent and historical lessons below.

Passing UI tests, building successfully, or finding a nearby synthetic record does not establish field safety. State limitations plainly and preserve fail-closed behavior.

## Non-negotiable safety boundaries

- The bundled database has historically contained 100,006 synthetic records. Synthetic data is not real AED coverage and must never be represented as field truth.
- Do not describe the app as ready for emergency reliance without a real, licensed, current AED dataset; validated provenance and attribution; current physical-device evidence; and a current safety audit.
- Emergency Mode must remain fully offline. It must not depend on remote AED APIs, online maps, online routing, cloud speech recognition, analytics, accounts, OpenAI APIs, or a network connection.
- Preserve the emergency-first instruction as the first visible and spoken guidance unless an explicit current safety brief changes it:

  `Call 999 or 112 now. If someone is unresponsive and not breathing normally, start CPR. If you are alone with the person, do not leave them unless instructed by emergency services. Send someone else for the AED if possible.`

- Preserve explicit warnings that AED data may be incomplete, outdated, inaccessible, or wrong and that emergency dispatchers may have more current information.
- Preserve fail-closed behavior when local coverage is absent, including the exact state `No offline data for this area` where the current UI contract uses it.
- Do not expose private cabinet codes unless the source explicitly marks them public and redistribution is permitted. Otherwise direct the user to emergency services for access information.
- Never bypass TLS verification, licensing restrictions, signatures, checksums, or importer safeguards to obtain or install data.

## Current-versus-historical update behavior

The current repository README states that the app performs no runtime update checks, background refresh, remote downloads, or in-app AED data installation. Treat that current repository contract as authoritative.

Earlier project work explored signed manifest-based data packs, SHA-256/signature verification, rollback, manual update UI, launch-time checks, and background refresh outside Emergency Mode. Do not assume that implementation is present or desired now. If a future specification reintroduces updates:

- all update work must occur outside Emergency Mode;
- an update must be canceled or blocked immediately when Emergency Mode begins;
- only authenticated, integrity-checked, licensed data may replace the last known-good local pack;
- installation must be atomic and rollback-capable;
- update failure must never impair the existing offline emergency dataset or launch flow.

## Working agreements

- Read the exact safety brief, named file, and acceptance copy before acting.
- Preserve literal emergency wording, control labels, spoken text, and accessibility labels unless explicitly asked to change them.
- Prefer extending the current SwiftUI, SQLite, CoreLocation, on-device speech, and importer architecture over speculative rewrites.
- Keep read-only audits non-mutating unless the user explicitly requests changes.
- For safety audits, provide an inventory, evidence, pass/fail boundary, residual risk, and exact blockers—not merely a feature recap.
- Preserve user-owned changes. For commit/push work, inspect the branch, remote, upstream divergence, recent history, and exact files; stage narrowly.
- Treat current repository state and current device/test evidence as stronger than prior-account summaries.

## Product and implementation context

The project is an offline-first native SwiftUI iPhone application designed around an iPhone 13 / iOS 18 workflow. Historical work included:

- emergency home, with-patient, and runner flows;
- local SQLite search, bounding-box prefiltering, Haversine distance, bearing, and ranking;
- CoreLocation position and heading;
- on-device speech recognition where supported and `AVSpeechSynthesizer` output;
- Siri/Shortcuts/App Intents launch paths appropriate for an iPhone 13 without an Action Button;
- importer safeguards for CSV, JSON, and GeoJSON;
- large-button, Dynamic Type, Voice Control, and accessibility-label support;
- offline database verification and deterministic UI-test launch fixtures;
- CI collection of iPhone 13 acceptance evidence and a formal safety QA audit.

Historical CI references included workflow run `28860110597`, job `85596292305`, and artifact `iphone13-qa-evidence` (`8135420408`). These identifiers are historical pointers only; do not treat them as current proof without fetching and validating the present artifacts and repository revision.

Historically, `QA_AUDIT.md` was the authoritative audit record. Recheck its current contents, referenced commit, device/runtime, dataset provenance, screenshots, test reports, and unresolved findings before citing it.

## Data provenance and licensing

Before importing or bundling real AED data, verify and record:

- source owner and acquisition date;
- written permission or an applicable redistribution license;
- required attribution;
- region and expected coverage;
- data age and update cadence;
- access-status semantics and cabinet-code policy;
- transformation/import version;
- source and output checksums;
- record counts, coordinate validation, duplicate handling, and rejected-row reasons.

Do not assume that The Circuit/BHF or any other restricted dataset may be redistributed. OpenStreetMap-style data also requires compliance with its source license and attribution obligations.

## Verification discipline

Inspect current scripts, Xcode project settings, schemes, and test targets before execution. Established checks include:

```bash
python3 Tools/verify_offline_db.py
Tools/validate_local.sh
```

With full Xcode and an appropriate simulator/runtime:

```bash
xcodebuild -project AEDNowOffline.xcodeproj \
  -scheme AEDNowOffline \
  -destination 'platform=iOS Simulator,name=iPhone 13,OS=18.7.8' \
  test
```

Use the closest installed iOS 18 iPhone 13 simulator only when the exact runtime is unavailable, and report that substitution. Simulator success does not replace physical-device testing.

For relevant changes, verify at minimum:

- cold launch and first emergency control;
- complete Airplane Mode operation;
- fresh, stale, denied, and unavailable location states;
- no local-data and malformed-data failure states;
- nearest-AED ranking and lookup latency with the bundled scale;
- on-device speech availability and fallback behavior;
- Siri/Shortcut-equivalent launch routing;
- largest Dynamic Type, VoiceOver/Voice Control labels, contrast, and touch targets;
- absence of unintended network/background APIs in the app target;
- exact emergency copy and spoken ordering;
- physical iPhone behavior before any readiness claim.

## Questions to recheck when relevant

- Is the bundled dataset still synthetic, or is there now a real licensed and current source?
- Does the current audit correspond to the current commit, data pack, iOS runtime, and physical device?
- Are there any network calls or background modes in the app target that violate Emergency Mode's offline boundary?
- If an update mechanism is proposed, does it preserve atomic rollback and immediate cancellation when Emergency Mode begins?
- Are accessibility and emergency launcher paths still correct for the supported iPhone and iOS versions?
