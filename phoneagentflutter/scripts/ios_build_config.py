"""iOS environment, signing and extension contracts; never logs private values."""
from datetime import datetime, timezone
from fnmatch import fnmatchcase
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
from urllib.parse import urlparse

from ios_invite_config import TEAM, InviteConfigurationError, contract
from trusted_caller_properties import read_credentials

COMMUNICATION_KEY = 'com.apple.developer.usernotifications.communication'

EXTENSIONS = {'TrustedCallerNotificationService': 'KXPushServiceExtension',
              'TrustedIdentityLiveActivity': 'KXLiveActivityExtension'}


def policy(environment, build_mode=None):
    environment = 'prod' if environment == 'pro' else environment
    if environment not in {'dev', 'test', 'prod'}:
        raise InviteConfigurationError('环境仅允许 dev/test/pro（或 prod）。')
    production = environment == 'prod'
    default_mode = {'dev': 'debug', 'test': 'profile', 'prod': 'release'}[environment]
    allowed_modes = {'debug', 'profile'} if environment == 'dev' else {default_mode}
    if build_mode is not None and build_mode not in allowed_modes:
        raise InviteConfigurationError('构建模式与环境不兼容。')
    credential = 'pro' if production else environment
    bundle = contract(environment)['PRODUCT_BUNDLE_IDENTIFIER']
    return {'environment': environment, 'credential': credential,
            'sdk': 'pro' if production else 'test', 'bundle': bundle,
            'apns': 'production' if production else 'development',
            'development': not production,
            'mode': build_mode or default_mode,
            'defines': f'.local/cloud-{credential}/ios-device-defines.json',
            'extensions': {name: bundle + '.' + suffix for name, suffix in EXTENSIONS.items()}}


def private_inputs(repo, environment, build_mode=None):
    config = policy(environment, build_mode)
    repo = Path(repo)
    path = repo / config['defines']
    for node in [path, *path.parents]:
        if node == repo:
            break
        if node.is_symlink():
            raise InviteConfigurationError('iOS 私有配置不允许链接。')
    try:
        values = json.loads(path.read_text())
    except (ValueError, OSError):
        raise InviteConfigurationError('iOS 私有参数文件缺失或无效。') from None
    if not isinstance(values, dict) or values.get('APP_ENV') != config['environment']:
        raise InviteConfigurationError('参数文件 APP_ENV 与所选环境不一致；临时 pro 配置不作正式交付。')
    for key, route in [('API_BASE_URL', 'aiassistant-api'),
                       ('SDK_API_BASE_URL', 'aiassistant-sdk-api'),
                       ('RUNTIME_API_BASE_URL', 'aiassistant-runtime')]:
        try:
            uri = urlparse(values[key])
            valid = (uri.scheme == 'https' and uri.hostname and not uri.username and
                     not uri.password and not uri.query and not uri.fragment and
                     uri.path == '/' + route + '/')
        except (ValueError, KeyError, TypeError):
            valid = False
        if config['environment'] != 'prod':
            valid = valid and uri.hostname == f'chakenai-{config["environment"]}.vvtech.tech'
        else:
            valid = valid and uri.hostname not in {'chakenai-dev.vvtech.tech', 'chakenai-test.vvtech.tech'}
        if not valid:
            raise InviteConfigurationError('三类服务地址必须独立且匹配所选环境。')
    for key in ['SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET']:
        if not isinstance(values.get(key), str) or not values[key].strip() or any(c in values[key] for c in '\r\n\0'):
            raise InviteConfigurationError('iOS 业务凭据缺失或无效。')
    read_credentials(repo, 'ios', config['credential'])
    return config, values


def validate_apns(info, signed, profile, environment):
    config = policy(environment)
    allowed = profile.get('Entitlements', {})
    if any(v != config['apns'] for v in [info.get('TrustedCallerAPNSEnvironment'),
                                        signed.get('aps-environment'), allowed.get('aps-environment')]):
        raise InviteConfigurationError('APNs plist、最终签名、描述文件与交付策略不一致。')
    if (signed.get('get-task-allow') is not config['development'] or
            allowed.get('get-task-allow') is not config['development']):
        raise InviteConfigurationError('开发/分发签名与交付策略不一致。')


def validate_communication(signed, profile):
    if (signed.get(COMMUNICATION_KEY) is not True or
            profile.get('Entitlements', {}).get(COMMUNICATION_KEY) is not True):
        raise InviteConfigurationError('主包通讯通知权限缺失或 profile 未授权。')


def validate_identity(info, signed, profile, bundle, environment, device=None):
    config = policy(environment)
    identifier = TEAM + '.' + bundle
    allowed = profile.get('Entitlements', {})
    if (info.get('CFBundleIdentifier') != bundle or
            signed.get('application-identifier') != identifier or
            signed.get('com.apple.developer.team-identifier') != TEAM or
            TEAM not in profile.get('TeamIdentifier', []) or
            not fnmatchcase(identifier, allowed.get('application-identifier', ''))):
        raise InviteConfigurationError('主包或扩展身份与签名/profile 不一致。')
    if (signed.get('get-task-allow') is not config['development'] or
            allowed.get('get-task-allow') is not config['development']):
        raise InviteConfigurationError('扩展签名类型与主包环境不一致。')
    expiry = profile.get('ExpirationDate')
    if not isinstance(expiry, datetime) or expiry.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise InviteConfigurationError('描述文件已失效。')
    if device and device not in profile.get('ProvisionedDevices', []):
        raise InviteConfigurationError('描述文件未授权目标 USB 设备。')


def profile_kind(profile):
    """Apple's device-list shape distinguishes distribution types without names."""
    development = profile.get('Entitlements', {}).get('get-task-allow')
    devices = profile.get('ProvisionedDevices')
    if profile.get('ProvisionsAllDevices') or type(development) is not bool:
        raise InviteConfigurationError('不支持企业或未知分发类型的描述文件。')
    if 'ProvisionedDevices' in profile:
        if not isinstance(devices, list) or not devices or any(not isinstance(d, str) or not d for d in devices):
            raise InviteConfigurationError('描述文件设备授权清单无效。')
        return 'development' if development else 'ad-hoc'
    if not development:
        return 'app-store'
    raise InviteConfigurationError('开发描述文件缺少设备授权清单。')


def select_profile(bundle, environment, device=None, main=False, profile_roots=None, identities=None):
    config = policy(environment)
    kind = 'development' if config['development'] else ('ad-hoc' if device else 'app-store')
    if identities is None:
        output = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
        identities = set(re.findall(r'\b[0-9A-F]{40}\b', output))
    roots = profile_roots or [Path.home() / 'Library/MobileDevice/Provisioning Profiles',
                             Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']
    candidates = []
    for root in roots:
        for path in Path(root).glob('*.mobileprovision'):
            result = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True)
            if result.returncode:
                continue
            profile = plistlib.loads(result.stdout)
            ent = profile.get('Entitlements', {})
            try:
                if profile_kind(profile) != kind:
                    continue
                signed = {**ent, 'application-identifier': TEAM + '.' + bundle}
                validate_identity({'CFBundleIdentifier': bundle}, signed, profile, bundle, environment, device)
                if main:
                    validate_communication(ent, profile)
                    if ent.get('aps-environment') != config['apns']:
                        continue
                for certificate in profile.get('DeveloperCertificates', []):
                    identity = hashlib.sha1(certificate).hexdigest().upper()
                    if identity in identities:
                        exact = ent.get('application-identifier') == TEAM + '.' + bundle
                        created = profile.get('CreationDate')
                        created = created.replace(tzinfo=timezone.utc).timestamp() if isinstance(created, datetime) else 0
                        coverage = len(set(profile.get('ProvisionedDevices', [])))
                        rank = (-coverage, not exact, -created, str(path), identity)
                        candidates.append((rank, path, identity, profile))
            except (ValueError, TypeError):
                continue
    if not candidates:
        raise InviteConfigurationError('缺少匹配分发类型、主包/扩展、设备、团队和 APNs 策略的有效签名。')
    _, path, identity, profile = min(candidates, key=lambda x: x[0])
    return Path(path), identity, profile


def signing_entitlements(profile, bundle, environment, main=False):
    allowed = profile['Entitlements']
    ent = {k: allowed[k] for k in ['get-task-allow', 'aps-environment'] if k in allowed}
    ent['application-identifier'] = TEAM + '.' + bundle
    ent['com.apple.developer.team-identifier'] = TEAM
    # Narrow an authorized wildcard keychain group to this exact identity.
    groups = allowed.get('keychain-access-groups', [])
    identifier = TEAM + '.' + bundle
    if any(fnmatchcase(identifier, group) for group in groups):
        ent['keychain-access-groups'] = [identifier]
    if main:
        validate_communication(allowed, profile)
        ent[COMMUNICATION_KEY] = True
        c = contract(policy(environment)['environment'])
        domains = ['applinks:' + c[k] for k in ['INVITE_ASSOCIATED_DOMAIN', 'INVITE_WEB_HOST']]
        if policy(environment)['development']:
            domains.append('applinks:agent.vvtech.tech')
        patterns = allowed.get('com.apple.developer.associated-domains', [])
        patterns = ['*'] if patterns == '*' else patterns
        if any(not any(fnmatchcase(d, p) for p in patterns) for d in domains):
            raise InviteConfigurationError('主包 profile 未授权邀请域名。')
        ent['com.apple.developer.associated-domains'] = domains
    return ent
