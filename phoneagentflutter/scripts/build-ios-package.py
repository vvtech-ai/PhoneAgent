#!/usr/bin/env python3
"""Build a verified, isolated iOS dev/test/pro IPA with explicit version inputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo

from ios_build_config import private_inputs, select_profile, signing_entitlements, validate_identity
from ios_invite_config import InviteConfigurationError
from ios_build_manifest import create_manifest, load_manifest, sha256, validate_package

ROOT = Path(__file__).resolve().parent.parent
FLUTTER = Path.home() / '.cache/phoneagent-flutter-3.32.0/flutter/bin/flutter'


def run(args, cwd=None, env=None, capture=False):
    return subprocess.run([str(x) for x in args], cwd=cwd, env=env, check=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mirror_lock(text):
    # These two dependencies explicitly declare pub.dev in pubspec.yaml.
    blocks = re.split(r'(?=^  [a-zA-Z0-9_]+:\n)', text, flags=re.M)
    return ''.join(b if b.startswith(('  qr:\n', '  pointycastle:\n')) else
                   b.replace('https://pub.dev', 'https://pub.flutter-io.cn') for b in blocks)


def snapshot(workspace, config):
    source = workspace / 'source'
    source.mkdir()
    files = run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
                ROOT, capture=True).stdout.decode().split('\0')
    hashes = {}
    for relative in filter(None, files):
        original, target = ROOT / relative, source / relative
        if not original.exists() and not original.is_symlink():
            continue  # Represent tracked deletions in the current worktree snapshot.
        target.parent.mkdir(parents=True, exist_ok=True)
        if original.is_symlink():
            target.symlink_to(os.readlink(original))
        else:
            hashes[relative] = digest(original)
            shutil.copy2(original, target)
            if digest(target) != hashes[relative]:
                raise InviteConfigurationError('复制时源码发生变化。')
    if any(digest(ROOT / p) != h for p, h in hashes.items()):
        raise InviteConfigurationError('创建快照时源码发生变化。')
    print('WORKTREE SNAPSHOT SHA256', hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(), flush=True)
    for relative in ['local.properties', config['defines']]:
        original, target = ROOT / relative, source / relative
        run(['git', 'check-ignore', '--quiet', relative], ROOT)
        if original.is_symlink():
            raise InviteConfigurationError('私有输入不允许链接。')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target)
        target.chmod(0o600)
        if digest(original) != digest(target):
            raise InviteConfigurationError('私有输入复制不一致。')
    inputs = {'defines': {'path': config['defines'], 'sha256': digest(source / config['defines'])},
              'trusted_caller': {'path': 'local.properties', 'sha256': digest(source / 'local.properties'),
                                 'key_prefix': 'trustedCaller.ios.' + config['credential']}}
    provenance = {'git_commit': run(['git', 'rev-parse', 'HEAD'], ROOT, capture=True).stdout.decode().strip(),
                  'snapshot_sha256': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
                  'dirty': bool(run(['git', 'status', '--porcelain'], ROOT, capture=True).stdout.strip())}
    (workspace / 'provenance.json').write_text(json.dumps({'source': provenance, 'inputs': inputs}))
    return source


def build(options):
    config, _ = private_inputs(ROOT, options.environment, options.build_mode)
    if config['development'] and not options.device:
        raise InviteConfigurationError('开发签名构建必须指定已连接的目标设备。')
    if options.device:
        with tempfile.TemporaryDirectory(prefix='ios-device-preflight-') as temporary:
            output = Path(temporary) / 'device.json'
            run(['xcrun', 'devicectl', 'device', 'info', 'details', '--device', options.device,
                 '--json-output', output], capture=True)
            if json.loads(output.read_text())['result']['connectionProperties']['transportType'] != 'wired':
                raise InviteConfigurationError('本次安装目标必须通过数据线连接。')
    bundles = [config['bundle'], *config['extensions'].values()]
    profiles = {b: select_profile(b, options.environment, options.device, main=b == config['bundle']) for b in bundles}
    workspace = Path(options.workspace)
    source = snapshot(workspace, config)
    env = os.environ.copy()
    env.update(PUB_HOSTED_URL='https://pub.flutter-io.cn', FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn',
               PHONEAGENT_IOS_ENV=config['environment'], PYTHONDONTWRITEBYTECODE='1')
    if json.loads(run([FLUTTER, '--version', '--machine'], source, env, True).stdout)['frameworkVersion'] != '3.32.0':
        raise InviteConfigurationError('必须使用 Flutter 3.32.0。')
    lock = source / 'pubspec.lock'
    lock.write_text(mirror_lock(lock.read_text()))
    run([FLUTTER, 'pub', 'get', '--enforce-lockfile'], source, env, True)
    if (ROOT / 'ios/Pods').is_dir():
        shutil.copytree(ROOT / 'ios/Pods', source / 'ios/Pods', symlinks=True)
    xcconfig = workspace / 'Build.xcconfig'
    public = run(['python3', '-B', source / 'scripts/ios_invite_config.py', 'settings',
                  '--environment', config['environment']], capture=True).stdout
    xcconfig.write_bytes(public + ('\nTRUSTED_CALLER_APNS_ENVIRONMENT=' + config['apns'] + '\n').encode())
    with xcconfig.open('a') as build_config:
        build_config.write('\nDEBUG_INFORMATION_FORMAT = dwarf-with-dsym\nGCC_GENERATE_DEBUGGING_SYMBOLS = YES\n')
    env['XCODE_XCCONFIG_FILE'] = str(xcconfig)
    print('BUILD', config['environment'], config['mode'], config['apns'], 'main + 2 extensions', flush=True)
    run([FLUTTER, 'build', 'ios', '--' + config['mode'], '--no-codesign', '--pub',
         '--build-name=' + options.build_name, '--build-number=' + str(options.build_number),
         '--dart-define-from-file=' + str(source / config['defines']),
         '--dart-define=ENABLE_MIGRATION_PREVIEWS=false', '-t', 'lib/main.dart'], source, env)
    if lock.read_text() != mirror_lock((ROOT / 'pubspec.lock').read_text()):
        raise InviteConfigurationError('依赖版本在构建中发生变化。')
    app = source / 'build/ios/iphoneos/Runner.app'
    apps = [*app.glob('PlugIns/*.appex'), app]
    if len(apps) != 3:
        raise InviteConfigurationError('必须完整构建两个可信扩展。')
    identity = profiles[config['bundle']][1]

    def sign(path, entitlement=None):
        args = ['codesign', '--force', '--sign', identity, '--timestamp=none']
        if entitlement:
            args += ['--entitlements', entitlement, '--generate-entitlement-der']
        run(args + [path], capture=True)

    for binary in sorted([*app.rglob('*.framework'), *app.rglob('*.dylib')], key=lambda p: len(p.parts), reverse=True):
        sign(binary)
    for item in apps:
        info = plistlib.loads((item / 'Info.plist').read_bytes())
        bundle = info['CFBundleIdentifier']
        if bundle not in profiles:
            raise InviteConfigurationError('发现未登记扩展身份。')
        profile_path, ext_identity, profile = profiles[bundle]
        # Nested code must use the same signing certificate as its containing app.
        if ext_identity != identity:
            profile_path, ext_identity, profile = select_profile(
                bundle, options.environment, options.device, main=item == app, identities={identity})
        shutil.copy2(profile_path, item / 'embedded.mobileprovision')
        ent = signing_entitlements(profile, bundle, options.environment, main=item == app)
        validate_identity(info, ent, profile, bundle, options.environment, options.device)
        path = workspace / (item.name + '.entitlements')
        path.write_bytes(plistlib.dumps(ent))
        sign(item, path)
    payload = workspace / 'Payload'
    payload.mkdir()
    shutil.copytree(app, payload / 'Runner.app', symlinks=True)
    # Retain matching native symbols alongside Payload inside the delivered archive.
    symbols = workspace / 'Symbols'
    for dsym in (source / 'build/ios').rglob('*.dSYM'):
        symbols.mkdir(exist_ok=True)
        target = symbols / dsym.name
        if not target.exists():
            shutil.copytree(dsym, target, symlinks=True)
    with __import__('zipfile').ZipFile(workspace / 'PhoneAgent.ipa', 'w', __import__('zipfile').ZIP_DEFLATED) as archive:
        for directory in [payload, symbols]:
            if not directory.exists():
                continue
            for path in directory.rglob('*'):
                if path.is_symlink():
                    raise InviteConfigurationError('产物不允许链接。')
                if path.is_file():
                    archive.write(path, path.relative_to(workspace))
    provenance = json.loads((workspace / 'provenance.json').read_text())
    create_manifest(workspace / 'PhoneAgent.ipa', options.artifact_name, config,
                    provenance['source'], provenance['inputs'], options.device, payload / 'Runner.app')


def verify(options):
    workspace = Path(options.workspace)
    source, app = workspace / 'source', workspace / 'Payload/Runner.app'
    config, _ = private_inputs(source, options.environment, options.build_mode)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info['CFBundleShortVersionString'] != options.build_name or str(info['CFBundleVersion']) != str(options.build_number):
        raise InviteConfigurationError('最终版本不匹配。')
    if run(['xcrun', 'lipo', '-archs', app / info['CFBundleExecutable']], capture=True).stdout.strip() != b'arm64':
        raise InviteConfigurationError('最终 App 必须为 ARM64。')
    run(['python3', '-B', source / 'scripts/verify_ios_invite_artifact.py', '--environment',
         config['environment'], '--artifact', app])
    run(['python3', '-B', source / 'tool/verify_trusted_sdk.py'], source)
    from trusted_caller_properties import read_credentials
    credentials = read_credentials(source, 'ios', config['credential'])
    generated = (source / 'ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m').read_text()
    if not all('@' + json.dumps(credentials[k], ensure_ascii=False) in generated for k in ['appKey', 'appSecret']):
        raise InviteConfigurationError('原生凭据与所选环境不一致。')
    expected = '0' if config['sdk'] == 'pro' else '1'
    if 'PHONEAGENT_TRUSTED_SDK_TEST != ' + expected not in generated:
        raise InviteConfigurationError('SDK 编译环境不一致。')
    if config['mode'] != 'debug' and not (app / 'Frameworks/App.framework/App').is_file():
        raise InviteConfigurationError('缺少 AOT 二进制。')
    for path in app.rglob('*'):
        if path.is_file() and (path.name.endswith(('.pem', '.keystore', 'device-defines.json')) or path.name == 'local.properties'):
            raise InviteConfigurationError('私有输入混入安装包。')
    symbol = workspace / 'Symbols/Runner.app.dSYM'
    if not symbol.is_dir():
        raise InviteConfigurationError('缺少原生 Runner 符号文件。')
    binary_uuid = run(['xcrun', 'dwarfdump', '--uuid', app / info['CFBundleExecutable']], capture=True).stdout.split()[1]
    symbol_uuid = run(['xcrun', 'dwarfdump', '--uuid', symbol], capture=True).stdout.split()[1]
    if binary_uuid != symbol_uuid:
        raise InviteConfigurationError('符号文件与安装包 UUID 不匹配。')
    manifest_path = workspace / 'PhoneAgent.ipa.build.json'
    manifest = load_manifest(manifest_path)
    validate_package(workspace / 'PhoneAgent.ipa', manifest_path, config['environment'],
                     options.build_name, options.build_number, manifest['artifact']['sha256'], options.device,
                     artifact_name=options.artifact_name, expected_mode=config['mode'])
    provenance = json.loads((workspace / 'provenance.json').read_text())
    if manifest['source'] != provenance['source'] or manifest['inputs'] != provenance['inputs']:
        raise InviteConfigurationError('清单与本次构建快照来源不符。')
    print('PASS version / ARM64 / main + extensions / environment credentials / APNs / matching symbols', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--environment', choices=['dev', 'test', 'pro', 'prod'], required=True)
    parser.add_argument('--build-name', required=True)
    parser.add_argument('--build-number', type=int, required=True)
    parser.add_argument('--build-mode', choices=['debug', 'profile', 'release'],
                        help='Explicit mode; dev also permits profile for standalone launch.')
    parser.add_argument('--device', help='Physical device UDID; required for dev/test. '
                        'For pro/prod, selects Ad Hoc direct install; omit for App Store.')
    parser.add_argument('--phase', choices=['build', 'verify'], help=argparse.SUPPRESS)
    parser.add_argument('--workspace', help=argparse.SUPPRESS)
    parser.add_argument('--artifact-name', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.build_name) or not 1 <= args.build_number <= 2147483647:
        parser.error('必须显式提供有效版本和构建号。')
    if args.phase:
        if not args.workspace:
            parser.error('阶段缺少本次工作目录。')
        if not args.artifact_name:
            parser.error('阶段缺少本次交付文件名。')
        (build if args.phase == 'build' else verify)(args)
        return
    config, _ = private_inputs(ROOT, args.environment, args.build_mode)
    common = ['--environment', args.environment, '--build-name', args.build_name,
              '--build-number', str(args.build_number), '--build-mode', config['mode']]
    if args.device:
        common += ['--device', args.device]
    command = [sys.executable, '-B', str(Path(__file__).resolve()), *common, '--workspace', '{workspace}']
    stamp = datetime.now(ZoneInfo('Asia/Shanghai')).strftime('%Y%m%d_%H%M%S')
    name = f'Phone_Agent_{config["credential"].upper()}_{args.build_name}_{args.build_number}_{config["credential"]}_{config["mode"]}_{stamp}.ipa'
    command += ['--artifact-name', name]
    run([sys.executable, '-B', ROOT / 'scripts/run-test-build.py',
         '--build-command', json.dumps(command + ['--phase', 'build']),
         '--verify-command', json.dumps(command + ['--phase', 'verify']),
         '--ios-environment', config['environment'],
         '--artifact', json.dumps({'source': 'PhoneAgent.ipa', 'name': name}),
         '--artifact', json.dumps({'source': 'PhoneAgent.ipa.build.json', 'name': name + '.build.json'})], ROOT)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError):
        print('iOS 构建/验证失败；保留未完成目录，未输出凭据。', file=sys.stderr)
        sys.exit(1)
