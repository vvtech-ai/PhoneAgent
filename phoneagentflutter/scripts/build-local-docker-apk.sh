#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
defines="$repo/.local/cloud-dev/device-defines.json"
local_defines="${TMPDIR:-/tmp}/phone-agent-local-device-defines.json"
adb_bin="${ADB:-/Users/woosha/Library/Android/sdk/platform-tools/adb}"
flutter_bin="${FLUTTER:-/Volumes/moveDisk/DevTools/flutter-3.32.0-sdk/bin/flutter}"
serial="${ANDROID_SERIAL:-}"

cleanup() { rm -f "$local_defines"; }
trap cleanup EXIT

[[ -f "$defines" ]] || { echo "missing $defines" >&2; exit 1; }
[[ -f "$repo/local.properties" && ! -L "$repo/local.properties" ]] || {
  echo 'missing root local.properties or redirected input; Gradle validates trusted fields' >&2; exit 1;
}
[[ -x "$adb_bin" ]] || { echo "missing adb: $adb_bin" >&2; exit 1; }
[[ -x "$flutter_bin" ]] || { echo "missing Flutter 3.32.0: $flutter_bin" >&2; exit 1; }

if [[ -z "$serial" ]]; then
  serial="$("$adb_bin" devices | awk '$2 == "device" { print $1; exit }')"
fi
[[ -n "$serial" ]] || { echo "no authorized Android device" >&2; exit 1; }

node - "$defines" "$local_defines" <<'NODE'
const fs = require('fs');
const [source, target] = process.argv.slice(2);
const path = require('path');
try {
const root = path.resolve(path.dirname(source));
if (!fs.realpathSync(source).startsWith(root + path.sep) || fs.realpathSync(root) !== root) {
  throw new Error('dev configuration must remain inside project .local/cloud-dev');
}
const config = JSON.parse(fs.readFileSync(source, 'utf8'));
if (!config || config.APP_ENV !== 'dev') {
  throw new Error('dev configuration environment mismatch');
}
for (const key of ['SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET']) {
  if (typeof config[key] !== 'string' || config[key].trim() === '' || /[\r\n\0]/.test(config[key])) {
    throw new Error(`missing dev credential: ${key}`);
  }
}
config.APP_ENV = 'dev';
config.API_BASE_URL = 'http://127.0.0.1:28080/aiassistant-api/';
config.SDK_API_BASE_URL = 'http://127.0.0.1:28082/aiassistant-sdk-api/';
config.RUNTIME_API_BASE_URL = 'http://127.0.0.1:28085/aiassistant-runtime/';
fs.writeFileSync(target, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });
} catch {
  console.error('Invalid local dev configuration; private contents not logged.');
  process.exit(1);
}
NODE

for port in 28080 28082 28085 28086; do
  "$adb_bin" -s "$serial" reverse "tcp:$port" "tcp:$port" >/dev/null
done

export PHONEAGENT_ANDROID_ENV=dev
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/Volumes/moveDisk/DevCaches/gradle}"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$repo"
"$flutter_bin" build apk --debug --no-pub --target-platform android-arm64 \
  --dart-define-from-file="$local_defines" -t lib/main.dart

apk="$repo/build/app/outputs/flutter-apk/app-debug.apk"
"$adb_bin" -s "$serial" install -r "$apk"
"$adb_bin" -s "$serial" shell am force-stop com.vvtech.aiassistant.dev
"$adb_bin" -s "$serial" shell monkey -p com.vvtech.aiassistant.dev \
  -c android.intent.category.LAUNCHER 1 >/dev/null

echo "installed $apk on $serial"
"$adb_bin" -s "$serial" reverse --list
