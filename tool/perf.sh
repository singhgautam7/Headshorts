#!/bin/sh
# tool/perf.sh <device> <out-name> [main|away|away_offline]
# Needs `python3 tool/feed_server.py` running on the host.
set -e
cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
rm -f build/app/outputs/flutter-apk/app-profile.apk build/perf/*.json
flutter build apk --profile --target-platform android-arm64 --target=integration_test/perf_test.dart --dart-define=SCENARIO="${3:-main}" >/dev/null
adb -s "$1" uninstall com.grs.news >/dev/null 2>&1 || true
flutter drive --no-dds --profile --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
  --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d "$1"
mkdir -p specs/kuber-parity/perf
for f in build/perf/*.json; do cp "$f" "specs/kuber-parity/perf/$2_$(basename "$f")"; done
