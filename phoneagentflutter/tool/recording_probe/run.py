#!/usr/bin/env python3
"""Opt-in isolated simulator verification; never touches ordinary app installs."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
SDK = Path('/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter')
ANDROID = Path('/Users/Eason/Library/Android/sdk')
OUTPUT = ROOT / '.local/recording-probe'


def run(args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def read(args):
    return run(args, capture_output=True, text=True).stdout.strip()


def build(args, log):
    with log.open('w') as target:
        run(args, cwd=ROOT, stdout=target, stderr=subprocess.STDOUT,
            env={**os.environ, 'PUB_HOSTED_URL': 'https://pub.flutter-io.cn',
                 'JAVA_HOME': '/Applications/Android Studio.app/Contents/jbr/Contents/Home'})


def wait_report(fetch):
    for _ in range(30):
        try:
            report = json.loads(fetch())
            if isinstance(report, dict) and 'success' in report:
                return report
        except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
            pass
        time.sleep(1)
    raise RuntimeError('Synthetic report unavailable; inspect isolated runtime state')


def android(device):
    if not device.startswith('emulator-'):
        raise RuntimeError('Explicit emulator required')
    adb = [ANDROID / 'platform-tools/adb', '-s', device]
    if read([*adb, 'get-state']) != 'device':
        raise RuntimeError('Selected emulator unavailable')
    def ordinary():
        return [line.strip() for line in read([*adb, 'shell', 'dumpsys', 'package', 'com.vvtech.aiassistant.dev']).splitlines()
                if 'firstInstallTime=' in line or 'lastUpdateTime=' in line]
    before = ordinary()
    build(['bash', ROOT / 'android/gradlew', '-p', ROOT / 'android', '-I', SOURCE / 'android/inject.gradle',
           '-Dphoneagent.recordingProbeSource=' + str(SOURCE / 'android'), ':app:assembleDebug',
           '-Ptarget=' + str(SOURCE / 'main.dart'), '-Ptarget-platform=android-arm64',
           '-Pdart-defines=' + base64.b64encode(b'ENABLE_SYNTHETIC_RECORDING_PROBE=true').decode(),
           '-Pdart-obfuscation=false', '-Ptrack-widget-creation=true', '-Ptree-shake-icons=false'], OUTPUT / 'android-build.log')
    metadata = json.loads((ROOT / 'build/app/outputs/apk/debug/output-metadata.json').read_text())
    bundle = 'com.vvtech.aiassistant.synthetic.recordingprobe'
    if metadata['applicationId'] != bundle or len(metadata['elements']) != 1:
        raise RuntimeError('Probe identity verification failed')
    apk = ROOT / 'build/app/outputs/apk/debug' / metadata['elements'][0]['outputFile']
    aapt = ANDROID / 'build-tools/36.1.0/aapt'
    permissions = read([aapt, 'dump', 'permissions', apk])
    forbidden = ['INTERNET', 'RECORD_AUDIO', 'CAMERA', 'CALL_PHONE', 'READ_CONTACTS',
                 'READ_CALL_LOG', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']
    if any('android.permission.' + item + "'" in permissions for item in forbidden):
        raise RuntimeError('Unexpected business permission in isolated probe')
    isolated_apk = OUTPUT / 'RecordingProbe.apk'
    shutil.copy2(apk, isolated_apk)
    run([*adb, 'install', '-r', isolated_apk], capture_output=True)
    run([*adb, 'shell', 'am', 'force-stop', bundle], capture_output=True)
    # Remove only this probe's old result, never audio or ordinary app data.
    run([*adb, 'shell', 'run-as', bundle, 'rm', '-f', 'no_backup/domestic-recordings/synthetic-probe-result.json'], capture_output=True)
    run([*adb, 'shell', 'am', 'start', '-n', bundle + '/com.vvtech.phone_agent.RecordingProbeActivity'], capture_output=True)
    report = wait_report(lambda: read([*adb, 'exec-out', 'run-as', bundle, 'cat', 'no_backup/domestic-recordings/synthetic-probe-result.json']))
    after = ordinary()
    if before != after:
        raise RuntimeError('Ordinary Android install metadata changed')
    return bundle, report, {'ordinaryInstallMetadataUnchanged': True, 'businessPermissionsAbsent': True}


def ios(device):
    booted = json.loads(read(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
    if not any(item['udid'] == device and item['state'] == 'Booted'
               for items in booted['devices'].values() for item in items):
        raise RuntimeError('Explicit booted iOS simulator required')
    def ordinary():
        try:
            path = Path(read(['xcrun', 'simctl', 'get_app_container', device, 'com.chaken.phoneagent.test', 'app']))
            info = plistlib.loads((path / 'Info.plist').read_bytes())
            executable = path / info['CFBundleExecutable']
            return (str(path), executable.stat().st_size, executable.stat().st_mtime_ns)
        except subprocess.CalledProcessError:
            return None
    before = ordinary()
    bundle = 'com.vvtech.phoneagent.synthetic.recordingprobe'
    app = OUTPUT / 'RecordingProbe.app'
    app.mkdir(parents=True, exist_ok=True)
    info = {'CFBundleIdentifier': bundle, 'CFBundleExecutable': 'RecordingProbe',
            'CFBundleName': 'Synthetic Recording Probe', 'CFBundleVersion': '1',
            'CFBundleShortVersionString': '1.0', 'CFBundlePackageType': 'APPL',
            'MinimumOSVersion': '15.0', 'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1],
            'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
            'UILaunchScreen': {}, 'FLTAssetsPath': 'flutter_assets'}
    with (app / 'Info.plist').open('wb') as target:
        plistlib.dump(info, target)
    build([SDK / 'bin/flutter', 'build', 'bundle', '--debug', '--no-pub', '--target-platform=ios',
           '--dart-define=ENABLE_SYNTHETIC_RECORDING_PROBE=true', '--target=' + str(SOURCE / 'main.dart'),
           '--asset-dir=' + str(OUTPUT / 'flutter_assets')], OUTPUT / 'ios-assets.log')
    shutil.copytree(OUTPUT / 'flutter_assets', app / 'flutter_assets', dirs_exist_ok=True)
    engine = SDK / 'bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator'
    frameworks = app / 'Frameworks'
    frameworks.mkdir(exist_ok=True)
    shutil.copytree(engine / 'Flutter.framework', frameworks / 'Flutter.framework', dirs_exist_ok=True)
    platform_sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    build(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-emit-library', '-module-name', 'PhoneAgentRecordingProbe',
           '-target', 'arm64-apple-ios15.0-simulator', '-sdk', platform_sdk, '-F', engine,
           '-framework', 'Flutter', '-framework', 'UIKit', '-Xlinker', '-install_name',
           '-Xlinker', '@rpath/libRecordingProbe.dylib', '-o', frameworks / 'libRecordingProbe.dylib',
           ROOT / 'ios/Runner/DomesticRecordingChannel.swift', SOURCE / 'ios/RecordingProbeInspector.swift'], OUTPUT / 'ios-swift.log')
    build(['xcrun', '--sdk', 'iphonesimulator', 'clang', '-fobjc-arc', '-fmodules',
           '-target', 'arm64-apple-ios15.0-simulator', '-isysroot', platform_sdk,
           '-framework', 'UIKit', '-framework', 'Foundation', '-F', engine, '-framework', 'Flutter',
           '-L', frameworks, '-lRecordingProbe', '-Wl,-rpath,@executable_path/Frameworks',
           '-Wl,-rpath,/usr/lib/swift', '-o', app / 'RecordingProbe', SOURCE / 'ios/RecordingProbeHost.m'], OUTPUT / 'ios-host.log')
    run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    run(['xcrun', 'simctl', 'install', device, app], capture_output=True)
    container = Path(read(['xcrun', 'simctl', 'get_app_container', device, bundle, 'data']))
    result = container / 'Library/Application Support/domestic-recordings/synthetic-probe-result.json'
    result.unlink(missing_ok=True)
    run(['xcrun', 'simctl', 'launch', '--terminate-running-process',
         '--stdout=' + str(OUTPUT / 'ios-runtime.stdout'), '--stderr=' + str(OUTPUT / 'ios-runtime.stderr'), device, bundle], capture_output=True)
    report = wait_report(result.read_text)
    if before != ordinary():
        raise RuntimeError('Ordinary iOS install metadata changed')
    return bundle, report, {'ordinaryInstallMetadataUnchanged': True, 'onlyEncoderAndSyntheticInspectorRegistered': True, 'businessPermissionsAbsent': True}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['android', 'ios'])
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    version = json.loads(read([SDK / 'bin/flutter', '--version', '--machine']))
    if version['frameworkVersion'] != '3.32.0' or version['dartSdkVersion'] != '3.8.0':
        raise RuntimeError('Fixed Flutter/Dart required')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = [path for path in SOURCE.rglob('*') if path.is_file() and path.suffix in {'.dart', '.py', '.kt', '.swift', '.m', '.xml', '.gradle'}]
    sources += [ROOT / 'lib/features/translation/data/recording/device_domestic_recording_encoder.dart']
    sources += ([ROOT / 'android/app/src/main/kotlin/com/vvtech/phone_agent/DomesticAacEncoder.kt',
                 ROOT / 'android/app/src/main/kotlin/com/vvtech/phone_agent/DomesticRecordingChannel.kt']
                if args.platform == 'android' else [ROOT / 'ios/Runner/DomesticRecordingChannel.swift'])
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    bundle, report, guards = (android if args.platform == 'android' else ios)(args.device)
    if any(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != expected for path, expected in hashes.items()):
        raise RuntimeError('Probe sources changed during validation; evidence rejected')
    evidence = {'platform': args.platform, 'device': args.device, 'bundleId': bundle,
                'report': report, 'guards': guards,
                'sources': hashes}
    (OUTPUT / (args.platform + '-evidence.json')).write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(evidence, ensure_ascii=False, indent=2))
    if report.get('success') is not True:
        raise RuntimeError('Actual synthetic AAC probe failed')


if __name__ == '__main__':
    main()
