#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Source your local Flutter/Xcode/Ruby environment before calling this script.
flutter --version | head -n 1 | grep -q 'Flutter 3.32.0 '
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --debug --no-codesign --no-pub
# Signing and device installation are separate gates; do not claim them here.
