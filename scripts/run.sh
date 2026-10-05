#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build -project DockPick.xcodeproj -scheme DockPick -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData -quiet
pkill -x DockPick || true
open build/DerivedData/Build/Products/Debug/DockPick.app
