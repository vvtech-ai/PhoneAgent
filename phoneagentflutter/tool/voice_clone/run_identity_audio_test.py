#!/usr/bin/env python3
"""Run the production audio policy with a fake session on an explicit simulator."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def run(*args):
    return subprocess.run([str(value) for value in args], check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', required=True)
    args = parser.parse_args()
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'booted', '-j'))
    if not any(device['udid'] == args.simulator for items in devices['devices'].values()
               for device in items):
        raise SystemExit('Explicit booted simulator required')
    output = ROOT / '.local/voice-clone'
    output.mkdir(parents=True, exist_ok=True)
    executable = output / 'identity-audio-test'
    source = ROOT / 'ios/IdentityCaptureSDK/Classes'
    sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
    run('xcrun', 'clang', '-isysroot', sdk, '-target', 'arm64-apple-ios15.5-simulator',
        '-fobjc-arc', '-fmodules', '-framework', 'Foundation', '-framework', 'AVFoundation',
        '-I', source, source / 'IdentityCaptureAudioConfiguration.m',
        ROOT / 'tool/voice_clone/identity_audio_test.m', '-o', executable)
    print(run('xcrun', 'simctl', 'spawn', args.simulator, executable))


if __name__ == '__main__':
    main()
