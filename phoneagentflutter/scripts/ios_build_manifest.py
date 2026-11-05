"""Strict, credential-free IPA provenance and signed-bundle inventory."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

from ios_build_config import policy, validate_identity
from ios_invite_config import TEAM, InviteConfigurationError
from verify_ios_invite_artifact import extract_ipa, read_command_plist, verify_app

SUFFIX = '.build.json'


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _exact(value, fields):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise InviteConfigurationError('构建清单字段缺失、未知或含非白名单内容。')


def _hash(value, length=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{' + str(length) + '}', value)


def validate_schema(data):
    _exact(data, ['schema_version', 'created_at', 'environment', 'sdk_environment', 'build_mode',
                  'version', 'source', 'inputs', 'target_device_sha256', 'artifact', 'bundles'])
    if type(data['schema_version']) is not int or data['schema_version'] != 1:
        raise InviteConfigurationError('不支持的构建清单版本。')
    config = policy(data['environment'], data['build_mode'])
    if data['environment'] != config['environment'] or data['sdk_environment'] != config['sdk'] or data['build_mode'] != config['mode']:
        raise InviteConfigurationError('清单环境或构建模式冲突。')
    _exact(data['version'], ['name', 'number'])
    version = data['version']
    if (not isinstance(version['name'], str) or not re.fullmatch(r'\d+\.\d+\.\d+', version['name']) or
            type(version['number']) is not int or not 1 <= version['number'] <= 2147483647):
        raise InviteConfigurationError('清单版本无效。')
    _exact(data['source'], ['git_commit', 'snapshot_sha256', 'dirty'])
    if not _hash(data['source']['git_commit'], 40) or not _hash(data['source']['snapshot_sha256']) or type(data['source']['dirty']) is not bool:
        raise InviteConfigurationError('清单源码来源无效。')
    _exact(data['inputs'], ['defines', 'trusted_caller'])
    _exact(data['inputs']['defines'], ['path', 'sha256'])
    _exact(data['inputs']['trusted_caller'], ['path', 'sha256', 'key_prefix'])
    if (data['inputs']['defines']['path'] != config['defines'] or
            data['inputs']['trusted_caller']['path'] != 'local.properties' or
            data['inputs']['trusted_caller']['key_prefix'] != 'trustedCaller.ios.' + config['credential'] or
            any(not _hash(item['sha256']) for item in data['inputs'].values())):
        raise InviteConfigurationError('清单配置来源与环境不一致。')
    if data['target_device_sha256'] is not None and not _hash(data['target_device_sha256']):
        raise InviteConfigurationError('清单设备摘要无效。')
    if config['development'] and data['target_device_sha256'] is None:
        raise InviteConfigurationError('开发包清单缺少目标设备。')
    _exact(data['artifact'], ['file', 'sha256', 'size'])
    artifact = data['artifact']
    if (not isinstance(artifact['file'], str) or not re.fullmatch(r'[A-Za-z0-9_.-]+\.ipa', artifact['file']) or
            not _hash(artifact['sha256']) or type(artifact['size']) is not int or artifact['size'] <= 0):
        raise InviteConfigurationError('清单 IPA 身份无效。')
    try:
        timestamp = datetime.fromisoformat(data['created_at'])
        if timestamp.tzinfo is None:
            raise ValueError()
    except (ValueError, TypeError):
        raise InviteConfigurationError('清单时间无效。') from None
    bundles = data['bundles']
    if not isinstance(bundles, list) or len(bundles) != 3:
        raise InviteConfigurationError('清单必须包含主包和两个扩展。')
    expected = {config['bundle'], *config['extensions'].values()}
    seen = set()
    for bundle in bundles:
        _exact(bundle, ['bundle_id', 'team', 'version_name', 'version_number', 'development',
                        'plist_apns', 'signed_apns', 'profile_apns', 'profile_uuid',
                        'profile_sha256', 'certificate_sha256'])
        identifier = bundle['bundle_id']
        if identifier not in expected or identifier in seen:
            raise InviteConfigurationError('清单扩展身份缺失、重复或跨环境。')
        seen.add(identifier)
        if (bundle['team'] != TEAM or bundle['version_name'] != version['name'] or
                bundle['version_number'] != str(version['number']) or
                bundle['development'] is not config['development'] or
                not _hash(bundle['profile_sha256']) or not _hash(bundle['certificate_sha256']) or
                not isinstance(bundle['profile_uuid'], str) or
                not re.fullmatch(r'[0-9A-Fa-f-]{36}', bundle['profile_uuid'])):
            raise InviteConfigurationError('清单签名、版本或 profile 摘要无效。')
        values = [bundle[k] for k in ['plist_apns', 'signed_apns', 'profile_apns']]
        if identifier == config['bundle']:
            if any(value != config['apns'] for value in values):
                raise InviteConfigurationError('清单主包 APNs 与策略冲突。')
        elif any(value not in {None, config['apns']} for value in values):
            raise InviteConfigurationError('清单扩展 APNs 与策略冲突。')


def load_manifest(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
        raise InviteConfigurationError('构建清单缺失、过大或为链接。')

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise InviteConfigurationError('构建清单含重复字段。')
            result[key] = value
        return result
    try:
        data = json.loads(path.read_text(), object_pairs_hook=unique)
        validate_schema(data)
        return data
    except (ValueError, TypeError):
        raise InviteConfigurationError('构建清单解析或合同校验失败。') from None


def bundle_inventory(app, environment, device=None):
    verify_app(app, environment)
    facts = []
    for item in [app, *sorted((app / 'PlugIns').glob('*.appex'))]:
        info = plistlib.loads((item / 'Info.plist').read_bytes())
        signed = read_command_plist(['codesign', '-d', '--entitlements', ':-', str(item)])
        profile_path = item / 'embedded.mobileprovision'
        profile = read_command_plist(['security', 'cms', '-D', '-i', str(profile_path)])
        validate_identity(info, signed, profile, info['CFBundleIdentifier'], environment, device)
        with tempfile.TemporaryDirectory(prefix='ios-signing-certificate-') as temporary:
            prefix = str(Path(temporary) / 'certificate')
            subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(item)],
                           capture_output=True, check=True)
            certificate = Path(prefix + '0').read_bytes()
        if certificate not in profile.get('DeveloperCertificates', []):
            raise InviteConfigurationError('实际签名证书不在 profile 授权范围。')
        facts.append({'bundle_id': info['CFBundleIdentifier'], 'team': signed['com.apple.developer.team-identifier'],
                      'version_name': info['CFBundleShortVersionString'], 'version_number': str(info['CFBundleVersion']),
                      'development': signed['get-task-allow'], 'plist_apns': info.get('TrustedCallerAPNSEnvironment'),
                      'signed_apns': signed.get('aps-environment'),
                      'profile_apns': profile['Entitlements'].get('aps-environment'),
                      'profile_uuid': profile['UUID'], 'profile_sha256': sha256(profile_path),
                      'certificate_sha256': hashlib.sha256(certificate).hexdigest()})
    if len({item['certificate_sha256'] for item in facts}) != 1:
        raise InviteConfigurationError('主包和扩展使用了不同签名证书。')
    return sorted(facts, key=lambda item: item['bundle_id'])


def create_manifest(ipa, name, config, source, inputs, device, app):
    data = {'schema_version': 1, 'created_at': datetime.now(timezone.utc).isoformat(),
            'environment': config['environment'], 'sdk_environment': config['sdk'], 'build_mode': config['mode'],
            'version': {'name': plistlib.loads((app / 'Info.plist').read_bytes())['CFBundleShortVersionString'],
                        'number': int(plistlib.loads((app / 'Info.plist').read_bytes())['CFBundleVersion'])},
            'source': source, 'inputs': inputs,
            'target_device_sha256': hashlib.sha256(device.lower().encode()).hexdigest() if device else None,
            'artifact': {'file': name, 'sha256': sha256(ipa), 'size': Path(ipa).stat().st_size},
            'bundles': bundle_inventory(app, config['environment'], device)}
    validate_schema(data)
    Path(str(ipa) + SUFFIX).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    return data


def validate_package(ipa, manifest_path, environment, version, number, expected_sha256, device=None,
                     artifact_name=None, expected_source=None, expected_mode=None):
    ipa = Path(ipa)
    if ipa.is_symlink() or not ipa.is_file():
        raise InviteConfigurationError('IPA 缺失或为链接。')
    data = load_manifest(manifest_path)
    config = policy(environment, expected_mode)
    if expected_mode is not None and data['build_mode'] != config['mode']:
        raise InviteConfigurationError('IPA 构建模式与明确选择不符；禁止安装。')
    if (data['environment'] != config['environment'] or data['version'] != {'name': version, 'number': number} or
            data['artifact']['file'] != (artifact_name or ipa.name)):
        raise InviteConfigurationError('IPA 清单与明确选择的环境、版本或文件名不符。')
    if (not _hash(expected_sha256) or data['artifact']['sha256'] != expected_sha256 or
            sha256(ipa) != expected_sha256 or data['artifact']['size'] != ipa.stat().st_size):
        raise InviteConfigurationError('IPA SHA256 或大小不匹配；禁止安装。')
    if expected_source and data['source']['snapshot_sha256'] != expected_source:
        raise InviteConfigurationError('源码快照与指定构建不符。')
    if device and data['target_device_sha256'] != hashlib.sha256(device.lower().encode()).hexdigest():
        raise InviteConfigurationError('此构建清单对应其他目标设备。')
    with tempfile.TemporaryDirectory(prefix='ios-manifest-verify-') as temporary:
        app = extract_ipa(ipa, Path(temporary))
        if data['build_mode'] != 'debug' and not (app / 'Frameworks/App.framework/App').is_file():
            raise InviteConfigurationError('AOT 构建缺少 App.framework 二进制。')
        if bundle_inventory(app, config['environment'], device) != data['bundles']:
            raise InviteConfigurationError('清单与实际主包/扩展签名内容不符。')
    return data
