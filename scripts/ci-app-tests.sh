#!/bin/bash
# Runs the app tests on the newest available iPhone simulator.
set -euo pipefail
ID=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
ios = sorted((r for r in data if "iOS" in r), key=lambda r: [int(x) for x in r.rsplit("iOS-", 1)[1].split("-")])
for runtime in reversed(ios):
    for d in data[runtime]:
        if d["name"].startswith("iPhone") and d.get("isAvailable", True):
            print(d["udid"]); sys.exit(0)
sys.exit("no iPhone simulator")
')
echo "Simulator: $ID"
xcodebuild test -project MedReport.xcodeproj -scheme MedReport -destination "id=$ID" CODE_SIGNING_ALLOWED=NO
