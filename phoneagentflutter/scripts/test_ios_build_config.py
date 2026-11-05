"""Environment/signing regressions use synthetic inputs, not local credentials."""
from copy import deepcopy
from datetime import datetime, timedelta
import json
from pathlib import Path
import tempfile
import unittest

from ios_build_config import (policy, private_inputs, validate_apns, validate_identity,
                              signing_entitlements, validate_communication, COMMUNICATION_KEY)
from ios_invite_config import InviteConfigurationError, TEAM


class IosBuildConfigTests(unittest.TestCase):
    def fixture(self, environment='test', bundle=None):
        p = policy(environment)
        bundle = bundle or p['bundle']
        ent = {'application-identifier': TEAM + '.' + bundle,
               'com.apple.developer.team-identifier': TEAM,
               'get-task-allow': p['development'], 'aps-environment': p['apns']}
        info = {'CFBundleIdentifier': bundle, 'TrustedCallerAPNSEnvironment': p['apns']}
        profile = {'TeamIdentifier': [TEAM], 'Entitlements': dict(ent),
                   'ExpirationDate': datetime.now() + timedelta(days=2),
                   'ProvisionedDevices': ['synthetic-device']}
        return info, ent, profile

    def test_communication_permission_must_be_signed_and_profile_authorized(self):
        for env in ['dev', 'test', 'prod']:
            info, ent, profile = self.fixture(env)
            ent[COMMUNICATION_KEY] = profile['Entitlements'][COMMUNICATION_KEY] = True
            validate_communication(ent, profile)
            for section in ['signed', 'profile']:
                for value in [None, False, 'true', 1]:
                    signed = deepcopy(ent);copy = deepcopy(profile)
                    (signed if section == 'signed' else copy['Entitlements'])[COMMUNICATION_KEY] = value
                    with self.assertRaises(InviteConfigurationError):validate_communication(signed, copy)

    def test_main_signing_retains_communication_but_never_grants_it_to_extensions(self):
        config = policy('test');_, _, profile = self.fixture()
        profile['Entitlements']['com.apple.developer.associated-domains'] = ['*']
        profile['Entitlements'][COMMUNICATION_KEY] = True
        signed = signing_entitlements(profile, config['bundle'], 'test', main=True)
        self.assertIs(signed.get(COMMUNICATION_KEY), True)
        extension = signing_entitlements(profile, config['extensions']['TrustedCallerNotificationService'], 'test')
        self.assertNotIn(COMMUNICATION_KEY, extension)
        profile['Entitlements'].pop(COMMUNICATION_KEY)
        with self.assertRaises(InviteConfigurationError):
            signing_entitlements(profile, config['bundle'], 'test', main=True)

    def test_environment_matrix_and_alias(self):
        for env, app, sdk, apns in [('dev', 'dev', 'test', 'development'),
                                    ('test', 'test', 'test', 'development'),
                                    ('pro', 'prod', 'pro', 'production')]:
            p = policy(env)
            self.assertEqual((p['environment'], p['sdk'], p['apns']), (app, sdk, apns))
            self.assertEqual(p['credential'], env)
            self.assertEqual(len(p['extensions']), 2)
            self.assertTrue(all(b.startswith(p['bundle'] + '.') for b in p['extensions'].values()))
        self.assertEqual(policy('pro'), policy('prod'))
        for bad in ['TEST', '', 'local']:
            with self.assertRaises(InviteConfigurationError):
                policy(bad)

    def test_apns_matrix(self):
        for env in ['dev', 'test', 'prod']:
            validate_apns(*self.fixture(env), env)

    def test_each_missing_or_wrong_apns_source_is_rejected(self):
        for source, key in [(0, 'TrustedCallerAPNSEnvironment'), (1, 'aps-environment'), (2, 'aps-environment')]:
            for value in [None, 'production', 'test', 42]:
                info, ent, profile = self.fixture()
                target = [info, ent, profile['Entitlements']][source]
                target[key] = value
                with self.subTest(source=source, value=value), self.assertRaises(InviteConfigurationError):
                    validate_apns(info, ent, profile, 'test')

    def test_consistent_ad_hoc_test_package_is_rejected_by_delivery_policy(self):
        info, ent, profile = self.fixture()
        info['TrustedCallerAPNSEnvironment'] = ent['aps-environment'] = profile['Entitlements']['aps-environment'] = 'production'
        ent['get-task-allow'] = profile['Entitlements']['get-task-allow'] = False
        with self.assertRaises(InviteConfigurationError):
            validate_apns(info, ent, profile, 'test')

    def test_development_permission_cannot_be_forged(self):
        for target in ['signed', 'profile']:
            info, ent, profile = self.fixture()
            (ent if target == 'signed' else profile['Entitlements'])['get-task-allow'] = False
            with self.assertRaises(InviteConfigurationError):
                validate_apns(info, ent, profile, 'test')

    def test_each_extension_exact_id_team_version_identity(self):
        p = policy('test')
        for bundle in p['extensions'].values():
            args = self.fixture(bundle=bundle)
            validate_identity(*args, bundle, 'test', 'synthetic-device')
            for section, key, wrong in [(0, 'CFBundleIdentifier', 'com.chaken.phoneagent.KXPushServiceExtension'),
                                        (1, 'application-identifier', TEAM + '.foreign'),
                                        (1, 'com.apple.developer.team-identifier', 'FOREIGN')]:
                parts = deepcopy(args);parts[section][key] = wrong
                with self.assertRaises(InviteConfigurationError):
                    validate_identity(*parts, bundle, 'test', 'synthetic-device')

    def test_expired_or_unregistered_device_rejected(self):
        args = self.fixture()
        with self.assertRaises(InviteConfigurationError):
            validate_identity(*args, policy('test')['bundle'], 'test', 'other-device')
        args[2]['ExpirationDate'] = datetime.now() - timedelta(days=1)
        with self.assertRaises(InviteConfigurationError):
            validate_identity(*args, policy('test')['bundle'], 'test')

    def test_authorized_wildcard_extension_is_narrowed(self):
        bundle = policy('test')['extensions']['TrustedCallerNotificationService']
        info, signed, profile = self.fixture(bundle=bundle)
        profile['Entitlements']['application-identifier'] = TEAM + '.*'
        profile['Entitlements']['keychain-access-groups'] = [TEAM + '.*']
        profile['Entitlements'].pop('aps-environment')
        ent = signing_entitlements(profile, bundle, 'test')
        self.assertEqual(ent['application-identifier'], TEAM + '.' + bundle)
        self.assertEqual(ent['keychain-access-groups'], [TEAM + '.' + bundle])
        self.assertNotIn('aps-environment', ent)
        validate_identity(info, ent, profile, bundle, 'test')

    def test_temporary_pro_input_rejected_without_rewriting(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t);p = root / policy('pro')['defines'];p.parent.mkdir(parents=True)
            p.write_text(json.dumps({'APP_ENV': 'test'}));before = p.read_bytes()
            with self.assertRaises(InviteConfigurationError):
                private_inputs(root, 'pro')
            self.assertEqual(before, p.read_bytes())

    def test_wrong_routes_and_symlink_never_fall_back(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t);p = root / policy('test')['defines'];p.parent.mkdir(parents=True)
            p.write_text(json.dumps({'APP_ENV': 'test', 'API_BASE_URL': 'https://chakenai-dev.vvtech.tech/aiassistant-api/'}))
            with self.assertRaises(InviteConfigurationError):
                private_inputs(root, 'test')
            p.unlink();p.symlink_to(root / 'missing')
            with self.assertRaises(InviteConfigurationError):
                private_inputs(root, 'test')


if __name__ == '__main__':
    unittest.main()
