#!/usr/bin/env python3
"""Reuse an isolated Flutter simulator host, never install on a physical device."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FLUTTER = '/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/flutter'
PACKAGE = 'com.vvtech.phoneagent.ui.clonecatalog'


def run(*args, **kwargs):
    return subprocess.run([str(v) for v in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', required=True)
    args = parser.parse_args()
    state = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'])
    if not any(d['udid'] == args.simulator and d['name'] == 'PhoneAgent-Clone-20261009'
               for group in json.loads(state)['devices'].values() for d in group):
        raise SystemExit('Dedicated clone simulator required')
    host = ROOT / '.local/ui-reference/ios-isolated/flutter-shell.app'
    if not host.is_dir():
        raise SystemExit('Build the existing isolated Flutter shell host first')
    output = ROOT / '.local/voice-clone'
    assets = output / 'catalog-assets'
    with (output / 'ios-catalog-build.log').open('w') as log:
        run(FLUTTER, 'build', 'bundle', '--debug', '--no-pub', '--target-platform=ios',
            '--target=tool/voice_clone/catalog_reference.dart', '--asset-dir=' + str(assets),
            cwd=ROOT, env={**os.environ, 'PUB_HOSTED_URL': 'https://pub.flutter-io.cn'},
            stdout=log, stderr=subprocess.STDOUT)
    app = output / 'catalog-reference.app'
    shutil.copytree(host, app, dirs_exist_ok=True)
    shutil.rmtree(app / 'flutter_assets')
    shutil.copytree(assets, app / 'flutter_assets')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    info['CFBundleIdentifier'] = PACKAGE
    info['CFBundleName'] = 'Clone Catalog Reference'
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    run('codesign', '--force', '--sign', '-', app, capture_output=True)
    run('xcrun', 'simctl', 'install', args.simulator, app, capture_output=True)
    run('xcrun', 'simctl', 'launch', args.simulator, PACKAGE, capture_output=True)
    print('Offline catalog reference launched on the dedicated simulator.')


if __name__ == '__main__':
    main()
