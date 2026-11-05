#!/usr/bin/env python3
"""Install an already-built clone-only test on its named isolated emulator."""
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
ADB = '/Users/Eason/Library/Android/sdk/platform-tools/adb'
AAPT = '/Users/Eason/Library/Android/sdk/build-tools/36.1.0/aapt'
SDK = '/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/'
DEVICE = 'emulator-5558'
PACKAGE = 'com.vvtech.aiassistant.ui.clonestage'


def read(*args):
    return subprocess.check_output([ADB, '-s', DEVICE, *args], text=True).strip()


def main():
    if read('emu', 'avd', 'name').splitlines()[0] != 'PhoneAgent_Clone_20261009':
        raise SystemExit('Dedicated clone emulator required')
    directory = ROOT / 'build/app/outputs/apk/debug'
    metadata = json.loads((directory / 'output-metadata.json').read_text())
    if metadata['applicationId'] != PACKAGE or len(metadata['elements']) != 1:
        raise SystemExit('Expected isolated clone-stage APK')
    apk = (directory / metadata['elements'][0]['outputFile']).resolve()
    if apk.parent != directory.resolve() or not apk.is_file():
        raise SystemExit('Invalid clone-stage APK path')
    permissions = subprocess.check_output([AAPT, 'dump', 'permissions', str(apk)], text=True)
    for permission in ['CAMERA', 'RECORD_AUDIO', 'CALL_PHONE', 'READ_CONTACTS', 'READ_CALL_LOG']:
        if "name='android.permission." + permission + "'" in permissions:
            raise SystemExit('Fixture retained a business permission')
    read('install', '-r', str(apk))  # No uninstall or data clearing, including failure paths.
    read('shell', 'am', 'start', '-n', PACKAGE + '/com.vvtech.phone_agent.MainActivity')
    endpoint = None
    for _ in range(30):
        process = subprocess.run([ADB, '-s', DEVICE, 'shell', 'pidof', PACKAGE],
                                 capture_output=True, text=True)
        pid = process.stdout.strip()
        if not pid:
            time.sleep(1)
            continue
        logs = read('logcat', '-d', '--pid=' + pid)
        urls = re.findall(r'The Dart VM service is listening on (http://127\.0\.0\.1:\d+/[^\s]+/)', logs)
        if urls:
            endpoint = urlparse(urls[-1])
            break
        time.sleep(1)
    if endpoint is None:
        raise SystemExit('Reference process did not expose its local VM service')
    port = read('forward', 'tcp:0', 'tcp:' + str(endpoint.port))
    uri = 'http://127.0.0.1:' + port + endpoint.path
    output = ROOT / '.local/voice-clone/android-stage-driver.log'
    try:
        with output.open('w') as log:
            result = subprocess.run([
                SDK + 'dart', 'run', 'tool/run_shared_stage.dart', 'android', DEVICE,
                uri, SDK + 'flutter'], cwd=ROOT,
                env={**os.environ, 'STAGE_GROUP': 'voice-clone'},
                stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise SystemExit('Clone stage failed; inspect the local driver log')
        print('Clone stage passed; screenshots and result saved locally; App retained.')
    finally:
        read('forward', '--remove', 'tcp:' + port)


if __name__ == '__main__':
    main()
