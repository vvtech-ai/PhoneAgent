#!/usr/bin/env python3
"""macOS test APK entry; private inputs never leave the project directory."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from trusted_caller_properties import read_credentials


class BuildInputError(Exception):
    pass


def private_file(repo, relative):
    root = repo / '.local'
    path = root / relative
    # Reject symlinks including ancestors, even if they point inside the repo.
    if any(p.is_symlink() for p in [path, *path.parents]
           if p != repo and repo in p.parents):
        raise BuildInputError('Android 私有输入路径不允许符号链接。')
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise BuildInputError('缺少工程内 Android 私有输入。')
    return path.resolve()


def build_arguments(repo, number, mode):
    try:
        read_credentials(repo, 'android', 'test')
    except ValueError as error:
        raise BuildInputError(str(error)) from None
    defines = private_file(repo, 'cloud-test/device-defines.json')
    signing = private_file(repo, 'android/signing/signing.properties')
    try:
        config = json.loads(defines.read_text())
    except (ValueError, OSError):
        raise BuildInputError('test 配置无法解析。') from None
    if not isinstance(config, dict):
        raise BuildInputError('test 配置必须为 JSON 对象。')
    expected = {'APP_ENV': 'test'}
    for key, route in [('API_BASE_URL', 'aiassistant-api'),
                       ('SDK_API_BASE_URL', 'aiassistant-sdk-api'),
                       ('RUNTIME_API_BASE_URL', 'aiassistant-runtime')]:
        expected[key] = f'https://chakenai-test.vvtech.tech/{route}/'
    if any(config.get(k) != v for k, v in expected.items()):
        raise BuildInputError('test 环境或服务地址与批准目标不一致。')
    for key in ['SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET']:
        if (not isinstance(config.get(key), str) or not config[key].strip() or
                any(c in config[key] for c in '\r\n\0')):
            raise BuildInputError(f'test 私有参数缺少 {key}。')
    # Java Properties decoding and certificate/password checks belong to Gradle.
    # Require a portable, fixed relative keystore path before starting Flutter.
    props = {}
    for line in signing.read_text().splitlines():
        if '=' in line and not line.lstrip().startswith(('#', '!')):
            key, value = line.split('=', 1)
            props[key.strip()] = value.strip()
    if any(not props.get(k) for k in ['signingStoreFile', 'signingKeyAlias',
                                      'signingStorePassword', 'signingKeyPassword']):
        raise BuildInputError('工程内签名属性不完整。')
    if props['signingStoreFile'] != 'registered.keystore':
        raise BuildInputError('signingStoreFile 必须为相对路径 registered.keystore。')
    private_file(repo, 'android/signing/registered.keystore')
    args = ['build', 'apk', f'--{mode}', '--pub', '--target-platform', 'android-arm64',
            '--build-name=1.0.53', f'--build-number={number}',
            f'--dart-define-from-file={defines}',
            '--dart-define=ENABLE_MIGRATION_PREVIEWS=false', '-t', 'lib/main.dart']
    return signing, args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-number', type=int, required=True)
    parser.add_argument('--build-mode', choices=['release', 'debug'], default='release')
    parser.add_argument('--plan-only', action='store_true')
    options = parser.parse_args()
    if not 1 <= options.build_number <= 2147483647:
        parser.error('build-number 必须在 1..2147483647 内')
    repo = Path(__file__).resolve().parent.parent
    signing, args = build_arguments(repo, options.build_number, options.build_mode)
    flutter = Path(os.environ.get('FLUTTER', str(
        Path.home() / '.cache/phoneagent-flutter-3.32.0/flutter/bin/flutter')))
    if options.plan_only:
        print(json.dumps({'TargetPackage': 'com.vvtech.aiassistant.test',
                          'Flutter': str(flutter), 'Arguments': args}, ensure_ascii=False))
        return 0
    env = os.environ.copy()
    env['JAVA_HOME'] = env.get('JAVA_HOME',
                             '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
    env['PATH'] = str(Path(env['JAVA_HOME']) / 'bin') + os.pathsep + env.get('PATH', '')
    env['PHONEAGENT_ANDROID_ENV'] = 'test'
    env['PHONEAGENT_TEST_SIGNING_PROPERTIES'] = str(signing)
    java = subprocess.run([str(Path(env['JAVA_HOME']) / 'bin/java'), '-version'],
                          capture_output=True, text=True, env=env)
    if java.returncode or 'version "17.' not in java.stderr:
        raise BuildInputError('构建必须使用已验证的 JDK17。')
    version = subprocess.run([str(flutter), '--version', '--machine'],
                             capture_output=True, text=True, env=env, cwd=repo)
    try:
        valid = version.returncode == 0 and json.loads(version.stdout)['frameworkVersion'] == '3.32.0'
    except (ValueError, KeyError):
        valid = False
    if not valid:
        raise BuildInputError('构建必须使用 Flutter 3.32.0。')
    # Flutter prioritizes Android Studio above JAVA_HOME. Give this process
    # an isolated settings file rather than modifying the user's global config.
    legacy = Path.home() / '.flutter_settings'
    if legacy.is_file():
        if json.loads(legacy.read_text()).get('jdk-dir') != env['JAVA_HOME']:
            raise BuildInputError('现有旧版 Flutter 设置须指向 JDK17。')
        return subprocess.run([str(flutter), *args], cwd=repo, env=env).returncode
    current = Path(env.get('XDG_CONFIG_HOME', str(Path.home() / '.config/flutter'))) / 'settings'
    settings = json.loads(current.read_text()) if current.is_file() else {}
    settings['jdk-dir'] = env['JAVA_HOME']
    with tempfile.TemporaryDirectory(prefix='phoneagent-flutter-settings-') as directory:
        (Path(directory) / 'settings').write_text(json.dumps(settings))
        env['XDG_CONFIG_HOME'] = directory
        return subprocess.run([str(flutter), *args], cwd=repo, env=env).returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (BuildInputError, OSError, ValueError):
        # Do not expose parsed configuration, passwords or subprocess stderr.
        print('test APK 构建失败：请检查工程内私有输入和 Flutter 3.32.0/JDK17。', file=sys.stderr)
        sys.exit(1)
