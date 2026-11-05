#!/usr/bin/env python3
"""Compile the production initialization guard on macOS; no SDK or device access."""
from pathlib import Path
import platform
import subprocess
import tempfile


def main():
    if platform.system() != 'Darwin':
        raise SystemExit('Requires macOS and Xcode; not an iOS SDK integration test.')
    root = Path(__file__).resolve().parents[2]
    source = root / 'ios/IdentityCaptureSDK/Classes'
    with tempfile.TemporaryDirectory(prefix='identity-sdk-initialization-') as temp:
        executable = Path(temp) / 'initialization-test'
        subprocess.run([
            'xcrun', '--sdk', 'macosx', 'clang', '-fobjc-arc', '-fblocks',
            '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation',
            '-I', str(source), str(source / 'IdentityCaptureSDKInitialization.m'),
            str(root / 'tool/voice_clone/identity_sdk_initialization_test.m'),
            '-o', str(executable),
        ], check=True)
        for run in range(2):
            print(f'Fresh process {run + 1}:', flush=True)
            subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    main()
