#!/usr/bin/env python3
"""Build only fixed UIKit initialization display in a separate simulator App."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid
from build_reference import HEAD, NATIVE, OUTPUT, SOURCE, info, read, run
from fixed_reference_sources import export_fixed, list_fixed, git
from derive_initialization_presentation import extract_initialization_presentation


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
    artifact = 'native-initialization'
    bundle_id = 'com.vvtech.phoneagent.ui.iosnative.initialization'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    app = OUTPUT / (artifact + '.app')
    if app.exists():
        shutil.rmtree(app)  # Managed build output only, never installed App data.
    app.mkdir()
    with (app / 'Info.plist').open('wb') as target:
        plistlib.dump(info(bundle_id), target)
    generated = OUTPUT / ('fixed-initialization-presentation-' + HEAD)
    extraction = extract_initialization_presentation(NATIVE, HEAD, generated)
    masonry = 'PhoneAgent/Pods/Masonry'
    implementations = [path for path in list_fixed(NATIVE, HEAD, masonry + '/Masonry')
                       if path.endswith('.m')]
    snapshot = OUTPUT / ('fixed-source-' + HEAD)
    policy = 'PhoneAgent/PhoneAgent/Core/Domain/Auth/AIInitializationPolicy.m'
    policy_hash = hashlib.sha256(git(NATIVE, 'show', HEAD + ':iOS/' + policy)).hexdigest()
    fixed = export_fixed(NATIVE, HEAD, snapshot, implementations, [masonry])
    host = SOURCE / 'initialization/InitializationReferenceHost.m'
    sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    sources = [host, generated / 'GeneratedInitializationPresentation.m',
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
                args.simulator, bundle_id]))
    evidence_sources = [*sources[:2], generated / 'GeneratedInitializationPresentation.h',
                        Path(__file__), SOURCE / 'derive_initialization_presentation.py',
                        SOURCE / 'fixed_reference_sources.py', SOURCE / 'build_reference.py']
    evidence = {
        'native_head': HEAD, 'bundle_id': bundle_id, 'simulator': args.simulator,
        'scope': 'Fixed presentation bytes; synthetic two-step actions and option data only',
        'extraction': extraction, 'fixed_masonry_sources': fixed,
        'fixed_policy_evidence': {policy: policy_hash},
        'sources': {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in evidence_sources},
    }
    (OUTPUT / (artifact + '-sources.json')).write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    print('Isolated fixed initialization display launched; no SDK or account services.')


if __name__ == '__main__':
    main()
