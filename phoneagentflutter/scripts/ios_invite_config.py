"""Public iOS invitation contracts and pre-signing checks; never prints defines."""
import argparse
import base64
import os
from pathlib import Path
import plistlib
import re
import sys

DOMAIN_KEY = 'com.apple.developer.associated-domains'
TEAM = '425F285BQA'
ENVIRONMENTS = {
    'prod': ('ioslink.chaken.ai', 'www.chaken.ai', 'phoneagent',
             'com.chaken.phoneagent'),
    'test': ('phoneagent-ioslink.vvtech.tech', 'chakenai-test.vvtech.tech',
             'phoneagent-test', 'com.chaken.phoneagent.test'),
    'dev': ('phoneagent-ioslink.vvtech.tech', 'chakenai-dev.vvtech.tech',
            'phoneagent-test', 'com.chaken.phoneagent.test'),
}


class InviteConfigurationError(ValueError):
    pass


def contract(environment):
    if environment not in ENVIRONMENTS:
        raise InviteConfigurationError('必须显式选择 prod/test/dev 环境。')
    domain, web, scheme, bundle = ENVIRONMENTS[environment]
    return {'INVITE_ASSOCIATED_DOMAIN': domain, 'INVITE_WEB_HOST': web,
            'INVITE_URL_SCHEME': scheme, 'PRODUCT_BUNDLE_IDENTIFIER': bundle}


def validate_domains(domains, environment):
    expected = contract(environment)
    required = {'applinks:' + expected[key] for key in
                ['INVITE_ASSOCIATED_DOMAIN', 'INVITE_WEB_HOST']}
    allowed = required | ({'applinks:agent.vvtech.tech'} if environment != 'prod' else set())
    if (not isinstance(domains, list) or
            not all(isinstance(x, str) for x in domains) or
            len(set(domains)) != len(domains) or
            not required.issubset(domains) or not set(domains).issubset(allowed)):
        raise InviteConfigurationError('邀请 Associated Domains 缺失、重复或串用环境。')


def dart_environment(encoded):
    values = []
    try:
        for item in encoded.split(','):
            if item:
                text = base64.b64decode(item, validate=True).decode('utf-8')
                key, separator, value = text.partition('=')
                if key == 'APP_ENV' and separator:
                    values.append(value)
    except (ValueError, UnicodeError):
        raise InviteConfigurationError('DART_DEFINES 编码无效（未输出内容）。') from None
    if len(values) > 1:
        raise InviteConfigurationError('APP_ENV 重复，无法唯一确定环境。')
    return values[0] if values else 'local'


def preflight(settings):
    environment = settings.get('PHONEAGENT_IOS_ENV', '')
    expected = contract(environment)
    runtime = dart_environment(settings.get('DART_DEFINES', ''))
    # Bare no-sign compilation is supported; a signed delivery needs APP_ENV.
    local_compile = (runtime == 'local' and environment == 'dev' and
                     settings.get('CODE_SIGNING_ALLOWED') == 'NO')
    if runtime != environment and not local_compile:
        raise InviteConfigurationError('APP_ENV 与 PHONEAGENT_IOS_ENV 不一致；显式传入同一环境。')
    if settings.get('CONFIGURATION') == 'Release' and environment == 'dev':
        raise InviteConfigurationError('dev 不允许 Release，与 AppConfig 门禁保持一致。')
    for key, value in expected.items():
        if settings.get(key) != value:
            raise InviteConfigurationError(key + ' 与环境契约不一致。')
    path = Path(settings['SRCROOT']) / settings.get('CODE_SIGN_ENTITLEMENTS', '')
    try:
        template = path.read_text()
        expanded = re.sub(r'\$\(([^)]+)\)',
                          lambda m: settings.get(m[1], m[0]), template)
        entitlements = plistlib.loads(expanded.encode())
        validate_domains(entitlements.get(DOMAIN_KEY), environment)
    except (OSError, plistlib.InvalidFileException):
        raise InviteConfigurationError('无法读取实际 CODE_SIGN_ENTITLEMENTS。') from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['settings', 'preflight'])
    parser.add_argument('--environment', choices=ENVIRONMENTS)
    args = parser.parse_args()
    try:
        if args.action == 'settings':
            values = contract(args.environment)
            print('PHONEAGENT_IOS_ENV=' + args.environment)
            for key, value in values.items():
                if key != 'PRODUCT_BUNDLE_IDENTIFIER':
                    print(key + '=' + value)
            print('// Expected Runner Bundle ID: ' + values['PRODUCT_BUNDLE_IDENTIFIER'])
        else:
            preflight(os.environ)
            print('iOS 邀请构建配置检查通过。')
        return 0
    except InviteConfigurationError as error:
        print('error: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
