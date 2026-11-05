"""Compile the real iOS plugin and verify ObjC lifecycle dispatch registration."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter-root')
    parser.add_argument('--source', default='ios/Runner/InviteChannel.swift')
    args = parser.parse_args()
    root = args.flutter_root
    if root is None:
        config = Path('ios/Flutter/Generated.xcconfig').read_text()
        root = next(line.split('=', 1)[1] for line in config.splitlines()
                    if line.startswith('FLUTTER_ROOT='))
    framework = Path(root) / 'bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64'
    sdk = subprocess.check_output(
        ['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='invite-callbacks-') as temporary:
        output = Path(temporary) / 'invite.ll'
        result = subprocess.run([
            'xcrun', 'swiftc', '-emit-ir', '-sdk', sdk,
            '-target', 'arm64-apple-ios16.1', '-F', str(framework),
            args.source, '-o', str(output),
        ], capture_output=True, text=True)
        if result.returncode:
            print(result.stderr)
            return result.returncode
        # Protocol metadata also contains selectors. Only the class's instance
        # method table proves the Swift implementation is exposed to ObjC.
        table = next((line for line in output.read_text().splitlines()
                      if line.startswith('@_INSTANCE_METHODS_') and
                      'InviteChannel' in line), '')
        selectors = [
            'application:didFinishLaunchingWithOptions:',
            'application:openURL:options:',
            'application:continueUserActivity:restorationHandler:',
        ]
        registered = {selector: selector in table for selector in selectors}
        near_match = 'nearly matches optional requirement' in result.stderr
        print(json.dumps({'registered': registered,
                          'nearMatchWarning': near_match}, indent=2))
        return 0 if all(registered.values()) and not near_match else 1


if __name__ == '__main__':
    raise SystemExit(main())
