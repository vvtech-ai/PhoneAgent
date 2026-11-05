"""Synthetic environment/signing regressions; never uses private credentials."""
import base64
from copy import deepcopy
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from ios_invite_config import (
    DOMAIN_KEY, TEAM, InviteConfigurationError, contract, dart_environment,
    preflight, validate_domains,
)
from verify_ios_invite_artifact import extract_ipa, validate_signed

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('test_build_entry', ROOT / 'scripts/run-test-build.py')
ENTRY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENTRY)


def encoded(value):
    return base64.b64encode(value.encode()).decode()


def fixture(environment):
    config = contract(environment)
    domains = ['applinks:' + config[key] for key in
               ['INVITE_ASSOCIATED_DOMAIN', 'INVITE_WEB_HOST']]
    from ios_build_config import policy
    p = policy(environment)
    info = {'TrustedCallerAPNSEnvironment': p['apns'], 'CFBundleIdentifier': config['PRODUCT_BUNDLE_IDENTIFIER'],
            'PhoneAgentInviteEnvironment': environment,
            'CFBundleURLTypes': [{'CFBundleURLSchemes': [config['INVITE_URL_SCHEME']]}]}
    signed = {'com.apple.developer.usernotifications.communication': True, 'aps-environment': p['apns'], 'get-task-allow': p['development'], DOMAIN_KEY: domains,
              'application-identifier': TEAM + '.' + info['CFBundleIdentifier'],
              'com.apple.developer.team-identifier': TEAM}
    profile = {'TeamIdentifier': [TEAM], 'Entitlements': {
        **signed, DOMAIN_KEY: ['*']}}
    return info, signed, profile


class IosInviteConfigurationTest(unittest.TestCase):
    def settings(self, environment, mode='Debug'):
        return {**contract(environment), 'PHONEAGENT_IOS_ENV': environment,
                'DART_DEFINES': encoded('APP_ENV=' + environment),
                'SRCROOT': str(ROOT / 'ios'), 'CONFIGURATION': mode,
                'CODE_SIGN_ENTITLEMENTS': ('Runner/Runner.entitlements' if mode == 'Release'
                                           else 'Runner/RunnerDebug.entitlements')}

    def test_each_environment_real_template(self):
        for environment, mode in [('dev', 'Debug'), ('test', 'Debug'),
                                  ('test', 'Profile'), ('prod', 'Release'),
                                  ('test', 'Release')]:
            with self.subTest(environment=environment, mode=mode):
                preflight(self.settings(environment, mode))

    def test_signed_contract_all_environments(self):
        for environment in ['prod', 'test', 'dev']:
            with self.subTest(environment=environment):
                validate_signed(*fixture(environment), environment)

    def test_original_duplicate_website_domain_rejected(self):
        for environment in ['prod', 'test', 'dev']:
            web = 'applinks:' + contract(environment)['INVITE_WEB_HOST']
            with self.assertRaises(InviteConfigurationError):
                validate_domains([web, web], environment)

    def test_foreign_environment_and_unexpanded_domains_rejected(self):
        for domains in [None, [], ['applinks:$(INVITE_ASSOCIATED_DOMAIN)'],
                        fixture('prod')[1][DOMAIN_KEY],
                        fixture('dev')[1][DOMAIN_KEY]]:
            with self.assertRaises(InviteConfigurationError):
                validate_domains(domains, 'test')

    def test_legacy_domain_allowed_only_nonproduction(self):
        for environment in ['test', 'dev']:
            domains = fixture(environment)[1][DOMAIN_KEY] + ['applinks:agent.vvtech.tech']
            validate_domains(domains, environment)
        with self.assertRaises(InviteConfigurationError):
            validate_domains(fixture('prod')[1][DOMAIN_KEY] + ['applinks:agent.vvtech.tech'], 'prod')

    def test_env_and_each_setting_mismatch_rejected(self):
        for key in ['PHONEAGENT_IOS_ENV', 'INVITE_ASSOCIATED_DOMAIN', 'INVITE_WEB_HOST',
                    'INVITE_URL_SCHEME', 'PRODUCT_BUNDLE_IDENTIFIER']:
            settings = self.settings('test')
            settings[key] = 'wrong'
            with self.subTest(key=key), self.assertRaises(InviteConfigurationError):
                preflight(settings)

    def test_empty_debug_entitlements_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'empty.entitlements'
            path.write_bytes(plistlib.dumps({}))
            settings = self.settings('test')
            settings['CODE_SIGN_ENTITLEMENTS'] = str(path)
            with self.assertRaises(InviteConfigurationError):
                preflight(settings)

    def test_invalid_or_repeated_app_env_never_echoes_defines(self):
        for value in ['not-base64', encoded('APP_ENV=test') + ',' + encoded('APP_ENV=prod')]:
            with self.assertRaises(InviteConfigurationError) as error:
                dart_environment(value)
            self.assertNotIn(value, str(error.exception))
        self.assertEqual(dart_environment(encoded('APP_ENV=test') + ',' + encoded('SECRET=synthetic')), 'test')

    def test_unsigned_local_compile_allowed_signed_local_rejected(self):
        settings = self.settings('dev')
        settings['DART_DEFINES'] = ''
        with self.assertRaises(InviteConfigurationError):
            preflight(settings)
        settings['CODE_SIGNING_ALLOWED'] = 'NO'
        preflight(settings)

    def test_dev_release_rejected(self):
        with self.assertRaises(InviteConfigurationError):
            preflight(self.settings('dev', 'Release'))

    def test_final_communication_permission_cannot_be_dropped_or_forged(self):
        key = 'com.apple.developer.usernotifications.communication'
        for source in ['signed', 'profile']:
            for value in [None, False, 'true', 1]:
                info, signed, profile = fixture('test')
                (signed if source == 'signed' else profile['Entitlements'])[key] = value
                with self.subTest(source=source, value=value), self.assertRaises(InviteConfigurationError):
                    validate_signed(info, signed, profile, 'test')

    def test_wrong_final_identity_environment_scheme_rejected(self):
        for section, key, value in [('info', 'CFBundleIdentifier', 'foreign'),
                                    ('info', 'PhoneAgentInviteEnvironment', 'dev'),
                                    ('info', 'CFBundleURLTypes', []),
                                    ('signed', 'application-identifier', 'foreign'),
                                    ('signed', 'com.apple.developer.team-identifier', 'foreign')]:
            info, signed, profile = fixture('test')
            (info if section == 'info' else signed)[key] = value
            with self.subTest(key=key), self.assertRaises(InviteConfigurationError):
                validate_signed(info, signed, profile, 'test')

    def test_missing_or_wrong_profile_permissions_rejected(self):
        for key, value in [(DOMAIN_KEY, []), (DOMAIN_KEY, 'not-an-array'),
                           (DOMAIN_KEY, ['applinks:foreign.test']),
                           ('application-identifier', 'foreign.*'),
                           ('com.apple.developer.team-identifier', 'foreign')]:
            info, signed, profile = fixture('test')
            profile['Entitlements'][key] = value
            with self.subTest(key=key), self.assertRaises(InviteConfigurationError):
                validate_signed(info, signed, profile, 'test')
        info, signed, profile = fixture('test')
        profile['TeamIdentifier'] = ['foreign']
        with self.assertRaises(InviteConfigurationError):
            validate_signed(info, signed, profile, 'test')

    def test_exact_profile_domains_allowed(self):
        info, signed, profile = fixture('test')
        profile['Entitlements'] = deepcopy(signed)
        validate_signed(info, signed, profile, 'test')

    def test_apple_profile_wildcard_string_allowed(self):
        info, signed, profile = fixture('test')
        profile['Entitlements'][DOMAIN_KEY] = '*'
        validate_signed(info, signed, profile, 'test')

    def test_ipa_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / 'synthetic.ipa'
            with zipfile.ZipFile(artifact, 'w') as archive:
                archive.writestr('../outside', 'synthetic')
            with self.assertRaises(InviteConfigurationError):
                extract_ipa(artifact, root / 'output')

    def test_export_entry_requires_ipa_environment_before_build(self):
        args = ['run-test-build.py', '--build-command', '["synthetic-build"]',
                '--verify-command', '["synthetic-verify"]',
                '--artifact', '{"source":"output/test.ipa","name":"test.ipa"}']
        with patch('sys.argv', args), patch.object(ENTRY, 'run_pipeline') as pipeline:
            with patch('sys.stderr'), self.assertRaises(SystemExit) as error:
                ENTRY.main()
            self.assertEqual(error.exception.code, 2)
            pipeline.assert_not_called()

    def test_export_rejects_ipa_without_manifest_before_build(self):
        args = ['run-test-build.py', '--build-command', '["synthetic-build"]',
                '--verify-command', '["synthetic-verify"]', '--ios-environment', 'test',
                '--artifact', '{"source":"test.ipa","name":"test.ipa"}']
        with patch('sys.argv', args), patch.object(ENTRY, 'run_pipeline') as pipeline:
            with patch('sys.stderr'), self.assertRaises(SystemExit):
                ENTRY.main()
            pipeline.assert_not_called()
        upper = list(args)
        upper[-1] = '{"source":"test.IPA","name":"test.IPA"}'
        with patch('sys.argv', upper), patch.object(ENTRY, 'run_pipeline') as pipeline:
            with patch('sys.stderr'), self.assertRaises(SystemExit):
                ENTRY.main()
            pipeline.assert_not_called()

    def test_export_automatically_checks_each_ipa_and_propagates_failure(self):
        from test_build_workspace import Artifact
        import subprocess
        artifacts = [Artifact('output/test.ipa', 'test.ipa'),
                     Artifact('output/test.apk', 'test.apk')]
        with patch.object(ENTRY.subprocess, 'run') as run:
            ENTRY.verify_ios_artifacts(Path('/synthetic'), artifacts, 'test', ROOT)
            self.assertEqual(run.call_count, 1)
            args = run.call_args.args[0]
            self.assertIn('test', args)
            self.assertIn('/synthetic/output/test.ipa', args)
            run.side_effect = subprocess.CalledProcessError(1, ['synthetic'])
            with self.assertRaises(subprocess.CalledProcessError):
                ENTRY.verify_ios_artifacts(Path('/synthetic'), artifacts, 'test', ROOT)

    def test_xcconfig_values_match_public_contract(self):
        values = dict(line.split(' = ', 1) for line in
                      (ROOT / 'ios/Flutter/Invite.xcconfig').read_text().splitlines()
                      if ' = ' in line)
        for environment in ['prod', 'test', 'dev']:
            expected = contract(environment)
            for prefix, key in [('DOMAIN', 'INVITE_ASSOCIATED_DOMAIN'),
                                ('WEB', 'INVITE_WEB_HOST'), ('SCHEME', 'INVITE_URL_SCHEME')]:
                self.assertEqual(values['PHONEAGENT_INVITE_' + prefix + '_' + environment], expected[key])


if __name__ == '__main__':
    unittest.main()
