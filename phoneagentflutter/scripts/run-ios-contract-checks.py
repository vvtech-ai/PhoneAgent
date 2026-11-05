#!/usr/bin/env python3
"""Credential-free local/CI checks; native mode requires macOS and CocoaPods gems."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(args, env=None):
    subprocess.run([str(a) for a in args], cwd=ROOT, env=env, check=True)


def python_checks():
    for pattern in ['test_ios_*.py', 'test_test_build_workspace.py', 'test_trusted_caller_properties.py']:
        run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'scripts', '-p', pattern, '-v'])
    run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tool',
         '-p', 'test_prepare_trusted_caller_credentials.py', '-v'])


def native_checks():
    if sys.platform != 'darwin':
        raise RuntimeError('原生检查必须在 macOS Runner 执行，不允许静默跳过。')
    run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tool',
         '-p', 'test_ios_apns_entitlements.py', '-v'])
    env = os.environ.copy()
    if not env.get('GEM_HOME'):
        # Homebrew CocoaPods keeps xcodeproj private to its installed runtime.
        roots = [Path('/opt/homebrew/Cellar/cocoapods'), Path('/usr/local/Cellar/cocoapods')]
        gems = sorted(p.parent.parent for root in roots for p in root.glob('*/libexec/gems/xcodeproj-*'))
        if gems:
            env['GEM_HOME'] = str(gems[-1])
    run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tool',
         '-p', 'test_trusted_identity_extension_wiring.py', '-v'], env)
    run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tool',
         '-p', 'test_trusted_notification_extension_wiring.py', '-v'], env)
    run(['ruby', 'tool/verify_trusted_extensions.rb'], env)
    cases = {'push_binding_state': ['TrustedCallerPushBindingState.m'],
             'push_binding_driver': ['TrustedCallerPushBindingState.m', 'TrustedCallerPushBindingDriver.m',
                                     'TrustedCallerIncomingDiagnostics.m'],
             'push_registration': ['TrustedCallerPushBindingState.m', 'TrustedCallerPushBindingDriver.m',
                                   'TrustedCallerIncomingDiagnostics.m'],
             'incoming_diagnostics': ['TrustedCallerIncomingDiagnostics.m']}
    sources = ROOT / 'ios/TrustedCallerSDK/Classes'
    with tempfile.TemporaryDirectory(prefix='ios-native-contracts-') as temporary:
        for name, files in cases.items():
            binary = Path(temporary) / name
            run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wno-nullability-completeness',
                 '-Wno-incomplete-implementation', '-framework', 'Foundation',
                 '-I' + str(ROOT / 'tool/trusted_push_registration_stubs'), '-I' + str(sources),
                 ROOT / f'tool/trusted_caller_{name}_test.m', *[sources / f for f in files], '-o', binary])
            run([binary])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true', help='Run native/Xcode wiring checks on macOS.')
    options = parser.parse_args()
    (native_checks if options.native else python_checks)()


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print('iOS 合同检查失败；检查 Runner 的 Python/Xcode/CocoaPods 工具链。', file=sys.stderr)
        sys.exit(1)
