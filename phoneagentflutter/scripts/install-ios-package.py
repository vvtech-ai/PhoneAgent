#!/usr/bin/env python3
"""Install only an explicitly selected, signed IPA matching its build manifest."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import json

from ios_build_manifest import sha256, validate_package
from ios_invite_config import InviteConfigurationError
from ios_build_config import policy
from verify_ios_invite_artifact import extract_ipa


def install(options):
    ipa, manifest = Path(options.ipa), Path(options.manifest or (options.ipa + '.build.json'))
    if ipa.is_symlink() or manifest.is_symlink() or not ipa.is_file() or not manifest.is_file():
        raise InviteConfigurationError('必须选择非链接的 IPA 和本次构建清单。')
    with tempfile.TemporaryDirectory(prefix='ios-verified-install-') as temporary:
        root = Path(temporary)
        frozen_ipa, frozen_manifest = root / ipa.name, root / 'manifest.json'
        shutil.copyfile(ipa, frozen_ipa)
        shutil.copyfile(manifest, frozen_manifest)
        data = validate_package(frozen_ipa, frozen_manifest, options.environment,
                                options.build_name, options.build_number, options.sha256,
                                options.device, expected_source=options.source_sha256)
        device_file = root / 'device.json'
        subprocess.run(['xcrun', 'devicectl', 'device', 'info', 'details', '--device', options.device,
                        '--json-output', str(device_file)], check=True, capture_output=True)
        if json.loads(device_file.read_text())['result']['connectionProperties']['transportType'] != 'wired':
            raise InviteConfigurationError('目标设备未通过数据线连接；禁止安装。')
        print('PASS IPA SHA256 / manifest / environment / version / source / main + extensions / USB device', flush=True)
        if options.verify_only:
            print('仅验证完成，未安装或启动。')
            return data
        app = extract_ipa(frozen_ipa, root / 'installation')
        if sha256(frozen_ipa) != options.sha256:
            raise InviteConfigurationError('验证后 IPA 发生变化；禁止安装。')
        subprocess.run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', options.device, str(app)], check=True)
        bundle = policy(options.environment)['bundle']
        subprocess.run(['xcrun', 'devicectl', 'device', 'info', 'apps', '--device', options.device,
                        '--bundle-id', bundle], check=True)
        if options.launch:
            subprocess.run(['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', options.device,
                            '--terminate-existing', bundle], check=True)
        return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa', required=True)
    parser.add_argument('--manifest', help='Defaults to <IPA>.build.json; mandatory file.')
    parser.add_argument('--environment', required=True, choices=['dev', 'test', 'pro', 'prod'])
    parser.add_argument('--build-name', required=True)
    parser.add_argument('--build-number', required=True, type=int)
    parser.add_argument('--sha256', required=True, help='Expected IPA SHA256 from this build output.')
    parser.add_argument('--source-sha256', help='Optional expected source snapshot SHA256.')
    parser.add_argument('--device', required=True, help='Physical device UDID from this build.')
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--launch', action='store_true', help='Launch after successful installation.')
    install(parser.parse_args())


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError):
        print('iOS 安装校验/执行失败；不卸载、不清数据、不换包或盲目重试。', file=sys.stderr)
        sys.exit(1)
