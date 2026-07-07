#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 -m py_compile Tools/import_aeds.py Tools/verify_offline_db.py
python3 Tools/verify_offline_db.py

swiftc -typecheck \
  AEDNowOffline/AppRouting.swift \
  AEDNowOffline/DistanceBearing.swift \
  AEDNowOffline/LocationSnapshot.swift \
  AEDNowOffline/AEDRepository.swift \
  AEDNowOffline/AEDSearchService.swift \
  AEDNowOffline/AEDDatabase.swift \
  AEDNowOffline/VoiceCommand.swift \
  AEDNowOffline/UITestConfiguration.swift \
  AEDNowOffline/UITestFixtures.swift

plutil -lint AEDNowOffline.xcodeproj/project.pbxproj AEDNowOffline/Info.plist >/dev/null
xmllint --noout AEDNowOffline.xcodeproj/xcshareddata/xcschemes/AEDNowOffline.xcscheme

echo "local validation passed"
