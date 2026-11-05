#!/usr/bin/env python3
"""Compile fixed original-audio display in a separate simulator-only App."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid
from build_reference import HEAD, NATIVE, OUTPUT, SOURCE, info, read, run
from fixed_reference_sources import export_fixed, list_fixed
from derive_original_audio_presentation import extract_original_audio_presentation


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', required=True)
    args = parser.parse_args()
    try:
        uuid.UUID(args.simulator)
    except ValueError:
        raise SystemExit('An explicit simulator UUID is required')
    devices = json.loads(read(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
    matches = [device for runtime, items in devices['devices'].items()
               if 'iOS' in runtime for device in items
               if device['udid'] == args.simulator and device['state'] == 'Booted']
    if len(matches) != 1:
        raise SystemExit('The explicitly selected iOS simulator must be booted')
    artifact = 'native-original-audio'
    bundle = 'com.vvtech.phoneagent.ui.iosnative.originalaudio'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    generated = OUTPUT / ('fixed-original-audio-presentation-' + HEAD)
    extraction = extract_original_audio_presentation(NATIVE, HEAD, generated)
    masonry = 'PhoneAgent/Pods/Masonry'
    implementations = [path for path in list_fixed(NATIVE, HEAD, masonry + '/Masonry')
                       if path.endswith('.m')]
    if not implementations:
        raise SystemExit('Fixed Masonry implementations missing')
    snapshot = OUTPUT / ('fixed-source-' + HEAD)
    fixed = export_fixed(NATIVE, HEAD, snapshot, implementations, [masonry])
    app = OUTPUT / (artifact + '.app')
    if app.exists():
        shutil.rmtree(app)  # Only generated output; never installed ordinary data.
    app.mkdir()
    with (app / 'Info.plist').open('wb') as target:
        plistlib.dump(info(bundle), target)
    host = SOURCE / 'original_audio/OriginalAudioReferenceHost.m'
    sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    sources = [host, generated / 'GeneratedOriginalAudioPresentation.m',
               *[snapshot / path for path in implementations]]
    command = ['xcrun', '--sdk', 'iphonesimulator', 'clang', '-fobjc-arc', '-fmodules',
               '-target', 'arm64-apple-ios15.0-simulator', '-isysroot', sdk,
               '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'QuartzCore',
               '-I', generated, '-I', snapshot / masonry,
               '-o', app / 'ReferenceHost', *sources]
    with (OUTPUT / (artifact + '-compile.log')).open('w') as target:
        run(command, stdout=target, stderr=subprocess.STDOUT)
    run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    run(['xcrun', 'simctl', 'install', args.simulator, app], capture_output=True)
    print(read(['xcrun', 'simctl', 'launch', '--terminate-running-process',
                '--stdout=' + str(OUTPUT / (artifact + '-runtime.stdout')),
                '--stderr=' + str(OUTPUT / (artifact + '-runtime.stderr')),
                args.simulator, bundle]))
    evidence = [*sources[:2], generated / 'GeneratedOriginalAudioPresentation.h',
                Path(__file__), SOURCE / 'derive_original_audio_presentation.py',
                SOURCE / 'fixed_reference_sources.py']
    (OUTPUT / (artifact + '-sources.json')).write_text(json.dumps({
        'native_head': HEAD, 'bundle_id': bundle, 'simulator': args.simulator,
        'scope': 'Fixed display/actions; host memory and local navigation only',
        'extraction': extraction, 'fixed_masonry_sources': fixed,
        'sources': {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in evidence},
    }, ensure_ascii=False, indent=2) + '\n')
    print('Isolated fixed original-audio display launched; no SDK or preference storage.')


if __name__ == '__main__':
    main()
