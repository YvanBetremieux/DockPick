#!/usr/bin/env bash
# Usage : scripts/test.sh [-only-testing:DockPickTests/GridLayoutTests]
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
RESULT="build/TestResults/$(date +%Y%m%d-%H%M%S).xcresult"
status=0
xcodebuild test -project DockPick.xcodeproj -scheme DockPick \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
  -resultBundlePath "$RESULT" -quiet "$@" || status=$?
if [[ -d "$RESULT" ]]; then
  xcrun xcresulttool get test-results summary --path "$RESULT" | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
print("Résultat : %s — %d réussis, %d échoués" % (d["result"], d["passedTests"], d["failedTests"]))'
fi
exit "$status"
