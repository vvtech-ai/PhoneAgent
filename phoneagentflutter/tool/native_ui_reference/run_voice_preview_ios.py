#!/usr/bin/env python3
"""Reuse the plugin-free simulator host for isolated voice button rendering."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FLUTTER = '/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/flutter'
PACKAGE = 'com.vvtech.phoneagent.ui.voicepreview'
SIMULATOR = 'C1837C32-89DC-440D-B18F-3B06CC24EC8E'


def run(*args, **kwargs):
    return subprocess.run([str(v) for v in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', required=True)
    args = parser.parse_args()
    state = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'])
    if args.simulator != SIMULATOR or not any(
            d['udid'] == SIMULATOR and d['name'] == 'PhoneAgent-UI-20261006'
            for group in json.loads(state)['devices'].values() for d in group):
        raise SystemExit('Explicit dedicated UI simulator must be booted')
    host = ROOT / '.local/ui-reference/ios-isolated/flutter-shell.app'
    if not host.is_dir():
        raise SystemExit('Build the existing plugin-free Flutter shell host first')
    output = ROOT / '.local/ui-reference/voice-preview-ink'
    output.mkdir(parents=True, exist_ok=True)
    assets = output / 'ios-assets'
    with (output / 'ios-build.log').open('w') as log:
        run(FLUTTER, 'build', 'bundle', '--debug', '--no-pub', '--target-platform=ios',
            '--target=tool/native_ui_reference/voice_preview_reference.dart',
            '--asset-dir=' + str(assets), cwd=ROOT,
            env={**os.environ, 'PUB_HOSTED_URL': 'https://pub.flutter-io.cn'},
            stdout=log, stderr=subprocess.STDOUT)
    app = output / 'voice-preview.app'
    shutil.copytree(host, app, dirs_exist_ok=True)
    shutil.rmtree(app / 'flutter_assets')
    shutil.copytree(assets, app / 'flutter_assets')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    info['CFBundleIdentifier'] = PACKAGE
    info['CFBundleName'] = 'Voice Preview Reference'
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    run('codesign', '--force', '--sign', '-', app, capture_output=True)
    run('xcrun', 'simctl', 'install', SIMULATOR, app, capture_output=True)
    run('xcrun', 'simctl', 'launch', SIMULATOR, PACKAGE, capture_output=True)
    print('Isolated voice button reference launched; no audio or accounts.')


if __name__ == '__main__':
    main()
