#!/usr/bin/env python3
"""Compile only fixed native credentials view plus fixed SnapKit for a simulator."""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
from pathlib import Path
from build_reference import ROOT, OUTPUT, info, read, run

REPOSITORY = Path('/Users/Eason/Desktop/Git/AIAssistant')
REVISION = 'bb9ff34966f40a3c2794a9a8b8e935669a9faa12'
VIEW = 'iOS/PhoneAgent/PhoneAgent/Features/TrustedIdentity/AITrustedIdentityCredentialsViewController.swift'
SNAPKIT = 'iOS/PhoneAgent/Pods/SnapKit/Sources'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', required=True)
    args = parser.parse_args()
    devices = json.loads(read(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
    active = [device for runtime, items in devices['devices'].items()
              if 'iOS' in runtime for device in items
              if device['udid'] == args.simulator and device['state'] == 'Booted']
    if len(active) != 1:
        raise SystemExit('Explicit booted simulator required')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    snapshot = OUTPUT / 'trusted-credentials-fixed-source'
    snapshot.mkdir(exist_ok=True)
    paths = read(['git', '-C', REPOSITORY, 'ls-tree', '-r', '--name-only', REVISION, SNAPKIT]).splitlines()
    paths = [path for path in paths if path.endswith('.swift')]
    if not paths:
        raise SystemExit('Fixed SnapKit sources missing')
    manifest = {'nativeCommit': REVISION, 'simulator': args.simulator, 'sources': {}}
    exported = []
    for path in [VIEW, *paths]:
        data = subprocess.check_output(['git', '-C', REPOSITORY, 'show', f'{REVISION}:{path}'])
        target = snapshot / Path(path).name
        target.write_bytes(data)
        manifest['sources'][path] = hashlib.sha256(data).hexdigest()
        exported.append(target)
    sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    common = ['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-swift-version', '5',
              '-target', 'arm64-apple-ios15.5-simulator', '-sdk', sdk]
    library = snapshot / 'libSnapKit.dylib'
    with (OUTPUT / 'native-trusted-credentials-snapkit.log').open('w') as log:
        run([*common, '-emit-library', '-emit-module', '-module-name', 'SnapKit',
             '-emit-module-path', snapshot / 'SnapKit.swiftmodule',
             '-Xlinker', '-install_name', '-Xlinker', '@rpath/libSnapKit.dylib',
             '-o', library, *exported[1:]], stdout=log, stderr=subprocess.STDOUT)
    bundle = 'com.vvtech.phoneagent.ui.iosnative.trustedcredentials'
    app = OUTPUT / 'native-trusted-credentials.app'
    if app.exists():
        shutil.rmtree(app)  # Only generated fixture, never installed ordinary App.
    (app / 'Frameworks').mkdir(parents=True)
    shutil.copy2(library, app / 'Frameworks/libSnapKit.dylib')
    values = info(bundle)
    values['MinimumOSVersion'] = '15.5'
    with (app / 'Info.plist').open('wb') as file:
        plistlib.dump(values, file)
    for image in sorted((ROOT / 'assets/images/trusted_identity').glob('*.png')):
        shutil.copy2(image, app / image.name)
        manifest['sources'][str(image.relative_to(ROOT))] = hashlib.sha256(image.read_bytes()).hexdigest()
    host = Path(__file__).with_name('TrustedCredentialsNativeHost.swift')
    manifest['sources'][str(host.relative_to(ROOT))] = hashlib.sha256(host.read_bytes()).hexdigest()
    with (OUTPUT / 'native-trusted-credentials-compile.log').open('w') as log:
        run([*common, '-parse-as-library', '-I', snapshot, '-L', snapshot, '-lSnapKit',
             '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks',
             '-Xlinker', '-rpath', '-Xlinker', '/usr/lib/swift',
             '-o', app / 'ReferenceHost', exported[0], host], stdout=log, stderr=subprocess.STDOUT)
    run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    run(['xcrun', 'simctl', 'install', args.simulator, app], capture_output=True)
    print(read(['xcrun', 'simctl', 'launch', '--terminate-running-process',
                '--stdout=' + str(OUTPUT / 'native-trusted-credentials-runtime.stdout'),
                '--stderr=' + str(OUTPUT / 'native-trusted-credentials-runtime.stderr'),
                args.simulator, bundle]))
    manifest['bundleId'] = bundle
    (OUTPUT / 'native-trusted-credentials-sources.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('Fixed native credentials view launched; no SDK or remote avatar URL')


if __name__ == '__main__':
    main()
