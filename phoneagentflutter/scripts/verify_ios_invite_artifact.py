"""Verify invitation configuration in a signed .app or .ipa, without resigning."""
import argparse
from fnmatch import fnmatchcase
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
import zipfile

from ios_build_config import policy, validate_apns, validate_identity, validate_communication

from ios_invite_config import (
    DOMAIN_KEY, ENVIRONMENTS, TEAM, InviteConfigurationError, contract,
    validate_domains,
)


def validate_signed(info, signed, profile, environment):
    validate_apns(info, signed, profile, environment)
    validate_communication(signed, profile)
    expected = contract(environment)
    validate_domains(signed.get(DOMAIN_KEY), environment)
    bundle = expected['PRODUCT_BUNDLE_IDENTIFIER']
    identifier = TEAM + '.' + bundle
    if info.get('CFBundleIdentifier') != bundle:
        raise InviteConfigurationError('最终 Bundle ID 与目标环境不一致。')
    if info.get('PhoneAgentInviteEnvironment') != environment:
        raise InviteConfigurationError('最终 Info.plist 缺少或串用邀请环境标记。')
    schemes = [scheme for entry in info.get('CFBundleURLTypes', [])
               for scheme in entry.get('CFBundleURLSchemes', [])
               if scheme.startswith('phoneagent')]
    if schemes != [expected['INVITE_URL_SCHEME']]:
        raise InviteConfigurationError('最终邀请 URL Scheme 缺失或串用环境。')
    if (signed.get('application-identifier') != identifier or
            signed.get('com.apple.developer.team-identifier') != TEAM):
        raise InviteConfigurationError('签名 App ID 或团队与已登记身份不一致。')
    allowed = profile.get('Entitlements', {})
    app_pattern = allowed.get('application-identifier', '')
    if (not isinstance(app_pattern, str) or not fnmatchcase(identifier, app_pattern) or
            allowed.get('com.apple.developer.team-identifier') != TEAM or
            TEAM not in profile.get('TeamIdentifier', [])):
        raise InviteConfigurationError('描述文件未授权当前 App ID/团队。')
    patterns = allowed.get(DOMAIN_KEY, [])
    if patterns == '*':
        patterns = ['*']
    if not isinstance(patterns, list) or not all(isinstance(x, str) for x in patterns):
        raise InviteConfigurationError('描述文件关联域名授权格式无效。')
    if any(not any(fnmatchcase(domain, pattern) for pattern in patterns)
           for domain in signed[DOMAIN_KEY]):
        raise InviteConfigurationError('描述文件未授权最终 Associated Domains。')


def read_command_plist(args):
    result = subprocess.run(args, capture_output=True, check=True)
    # codesign sends diagnostics to stderr; never echo entire profiles/entitlements.
    return plistlib.loads(result.stdout)


def verify_app(app, environment):
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)],
                   capture_output=True, check=True)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    signed = read_command_plist(['codesign', '-d', '--entitlements', ':-', str(app)])
    profile = read_command_plist([
        'security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')])
    validate_signed(info, signed, profile, environment)
    validate_identity(info, signed, profile, info['CFBundleIdentifier'], environment)
    expected = policy(environment)['extensions']
    extensions = list((app / 'PlugIns').glob('*.appex'))
    seen = set()
    for extension in extensions:
        ext_info = plistlib.loads((extension / 'Info.plist').read_bytes())
        bundle = ext_info.get('CFBundleIdentifier')
        if bundle not in expected.values() or bundle in seen:
            raise InviteConfigurationError('扩展身份错误或重复。')
        seen.add(bundle)
        ext_signed = read_command_plist(['codesign', '-d', '--entitlements', ':-', str(extension)])
        ext_profile = read_command_plist(['security', 'cms', '-D', '-i', str(extension / 'embedded.mobileprovision')])
        validate_identity(ext_info, ext_signed, ext_profile, bundle, environment)
        for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
            if ext_info.get(key) != info.get(key):
                raise InviteConfigurationError('扩展版本与主包不一致。')
    if seen != set(expected.values()):
        raise InviteConfigurationError('最终安装包缺少可信电话扩展。')


def extract_ipa(artifact, destination):
    with zipfile.ZipFile(artifact) as archive:
        for member in archive.infolist():
            target = destination / member.filename
            mode = member.external_attr >> 16
            if (not target.resolve().is_relative_to(destination.resolve()) or
                    stat.S_ISLNK(mode)):
                raise InviteConfigurationError('IPA 包含越界路径或符号链接。')
            archive.extract(member, destination)
            if not member.is_dir() and mode:
                target.chmod(mode & 0o777)
    apps = list((destination / 'Payload').glob('*.app'))
    if len(apps) != 1:
        raise InviteConfigurationError('IPA 必须包含唯一主 App。')
    return apps[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--environment', required=True, choices=ENVIRONMENTS)
    parser.add_argument('--artifact', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.artifact.suffix == '.ipa' and args.artifact.is_file():
            with tempfile.TemporaryDirectory(prefix='ios-invite-verify-') as temporary:
                verify_app(extract_ipa(args.artifact, Path(temporary)), args.environment)
        elif args.artifact.suffix == '.app' and args.artifact.is_dir():
            verify_app(args.artifact, args.environment)
        else:
            raise InviteConfigurationError('必须传入现有签名 .app 或 .ipa。')
        print('iOS ' + args.environment + ' 最终签名邀请配置检查通过。')
        return 0
    except InviteConfigurationError as error:
        print('error: ' + str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError,
            plistlib.InvalidFileException, zipfile.BadZipFile,
            subprocess.CalledProcessError):
        print('error: 最终邀请配置或签名验证失败；不得交付为已验证产物。', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
