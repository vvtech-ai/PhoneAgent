"""Manifest privacy, artifact identity and fail-before-install regressions."""
from argparse import Namespace
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from ios_build_config import policy
from ios_build_manifest import create_manifest, load_manifest, validate_schema, validate_package
from ios_invite_config import InviteConfigurationError, TEAM

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('ios_install_entry', ROOT / 'scripts/install-ios-package.py')
INSTALL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSTALL)
DEVICE = 'synthetic-device'


def fixture(ipa):
    p = policy('test')
    bundle = lambda b: {'bundle_id': b, 'team': TEAM, 'version_name': '1.0.52', 'version_number': '45',
                        'development': True, 'plist_apns': 'development' if b == p['bundle'] else None,
                        'signed_apns': 'development' if b == p['bundle'] else None,
                        'profile_apns': 'development' if b == p['bundle'] else None,
                        'profile_uuid': '00000000-0000-0000-0000-000000000000',
                        'profile_sha256': 'a' * 64, 'certificate_sha256': 'b' * 64}
    return {'schema_version': 1, 'created_at': '2026-10-22T00:00:00+00:00', 'environment': 'test',
            'sdk_environment': 'test', 'build_mode': 'profile', 'version': {'name': '1.0.52', 'number': 45},
            'source': {'git_commit': 'a' * 40, 'snapshot_sha256': 'c' * 64, 'dirty': True},
            'inputs': {'defines': {'path': p['defines'], 'sha256': 'd' * 64},
                       'trusted_caller': {'path': 'local.properties', 'sha256': 'e' * 64,
                                          'key_prefix': 'trustedCaller.ios.test'}},
            'target_device_sha256': hashlib.sha256(DEVICE.encode()).hexdigest(),
            'artifact': {'file': ipa.name, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
                         'size': ipa.stat().st_size},
            'bundles': sorted([bundle(b) for b in [p['bundle'], *p['extensions'].values()]], key=lambda b: b['bundle_id'])}


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.ipa = Path(self.temp.name) / 'test.ipa';self.ipa.write_bytes(b'synthetic signed archive')
        self.app = Path(self.temp.name) / 'Runner.app'
        aot = self.app / 'Frameworks/App.framework/App'
        aot.parent.mkdir(parents=True);aot.write_bytes(b'synthetic AOT binary')
        self.path = Path(str(self.ipa) + '.build.json');self.data = fixture(self.ipa);self.save()

    def save(self):
        self.path.write_text(json.dumps(self.data))

    def check(self, **changes):
        args = {'ipa': self.ipa, 'manifest_path': self.path, 'environment': 'test', 'version': '1.0.52',
                'number': 45, 'expected_sha256': self.data['artifact']['sha256'], 'device': DEVICE}
        args.update(changes)
        return validate_package(**args)

    def options(self, **changes):
        args = dict(ipa=str(self.ipa), manifest=None, environment='test', build_name='1.0.52', build_number=45,
                    sha256=self.data['artifact']['sha256'], source_sha256=None, device=DEVICE,
                    verify_only=True, launch=False)
        args.update(changes);return Namespace(**args)

    def test_valid_schema_and_frozen_inventory_match(self):
        self.assertEqual(load_manifest(self.path), self.data)
        with patch('ios_build_manifest.extract_ipa', return_value=self.app), patch(
                'ios_build_manifest.bundle_inventory', return_value=self.data['bundles']):
            self.assertEqual(self.check(expected_source='c' * 64), self.data)

    def test_dev_profile_keeps_dev_inputs_and_requires_selected_mode(self):
        self.data.update(environment='dev')
        self.data['inputs']['defines']['path'] = policy('dev')['defines']
        self.data['inputs']['trusted_caller']['key_prefix'] = 'trustedCaller.ios.dev'
        self.save()
        with patch('ios_build_manifest.extract_ipa', return_value=self.app), patch(
                'ios_build_manifest.bundle_inventory', return_value=self.data['bundles']):
            self.assertEqual(self.check(environment='dev', expected_mode='profile'), self.data)
        with patch('ios_build_manifest.extract_ipa') as extract:
            with self.assertRaises(InviteConfigurationError):
                self.check(environment='dev', expected_mode='debug')
            extract.assert_not_called()

    def test_profile_missing_aot_binary_is_rejected(self):
        (self.app / 'Frameworks/App.framework/App').unlink()
        with patch('ios_build_manifest.extract_ipa', return_value=self.app), patch(
                'ios_build_manifest.bundle_inventory', return_value=self.data['bundles']):
            with self.assertRaises(InviteConfigurationError):self.check()

    def test_creation_records_current_inputs_and_never_copies_credentials(self):
        import plistlib
        app = self.app
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.0.52', 'CFBundleVersion': '45'}))
        with patch('ios_build_manifest.bundle_inventory', return_value=self.data['bundles']):
            data = create_manifest(self.ipa, self.ipa.name, policy('test'), self.data['source'],
                                   self.data['inputs'], DEVICE, app)
            self.assertEqual(data['artifact'], self.data['artifact'])
            self.assertEqual(data['source'], self.data['source'])
            self.assertNotIn('appSecret', self.path.read_text())
            self.assertNotIn(DEVICE, self.path.read_text())
            self.assertEqual(load_manifest(self.path), data)

    def test_private_or_unknown_fields_rejected_at_every_level(self):
        for section in [None, 'source', 'artifact', 'version', 'inputs', 'bundles']:
            data = deepcopy(self.data)
            target = data if section is None else data[section][0] if section == 'bundles' else data[section]
            target['appSecret'] = 'must-not-be-emitted'
            with self.subTest(section=section), self.assertRaises(InviteConfigurationError):
                validate_schema(data)
        data = deepcopy(self.data);data['inputs']['trusted_caller']['appKey'] = 'secret'
        with self.assertRaises(InviteConfigurationError):validate_schema(data)

    def test_duplicate_fields_and_oversized_or_linked_manifest_rejected(self):
        self.path.write_text('{"schema_version":1,"schema_version":1}')
        with self.assertRaises(InviteConfigurationError):load_manifest(self.path)
        self.path.write_text(' ' * 65537)
        with self.assertRaises(InviteConfigurationError):load_manifest(self.path)
        self.path.unlink();self.path.symlink_to(self.ipa)
        with self.assertRaises(InviteConfigurationError):load_manifest(self.path)

    def test_wrong_environment_version_name_hash_source_or_device_stop_before_extract(self):
        cases = [{'environment': 'dev'}, {'version': '1.0.53'}, {'number': 46},
                 {'artifact_name': 'old.ipa'}, {'expected_sha256': '0' * 64},
                 {'expected_source': 'f' * 64}, {'device': 'other-device'}]
        for case in cases:
            with self.subTest(case=case), patch('ios_build_manifest.extract_ipa') as extract:
                with self.assertRaises(InviteConfigurationError):self.check(**case)
                extract.assert_not_called()

    def test_modified_ipa_rejected_even_with_same_version(self):
        self.ipa.write_bytes(b'replaced archive')
        with self.assertRaises(InviteConfigurationError):self.check()

    def test_actual_signed_inventory_cannot_be_replaced_by_manifest(self):
        facts = deepcopy(self.data['bundles']);facts[0]['profile_sha256'] = '0' * 64
        with patch('ios_build_manifest.extract_ipa', return_value=self.app), patch(
                'ios_build_manifest.bundle_inventory', return_value=facts):
            with self.assertRaises(InviteConfigurationError):self.check()

    def test_missing_foreign_or_duplicate_extension_rejected(self):
        for transform in ['missing', 'duplicate', 'foreign']:
            data = deepcopy(self.data)
            if transform == 'missing':data['bundles'].pop()
            elif transform == 'duplicate':data['bundles'][1] = data['bundles'][0]
            else:data['bundles'][1]['bundle_id'] = 'com.chaken.phoneagent.KXPushServiceExtension'
            with self.assertRaises(InviteConfigurationError):validate_schema(data)

    def test_wrong_apns_signing_or_private_path_rejected(self):
        for mutate in [lambda d: d['bundles'][0].update(plist_apns='production'),
                       lambda d: d['bundles'][0].update(development=False),
                       lambda d: d['inputs']['defines'].update(path='../local.properties'),
                       lambda d: d['inputs']['trusted_caller'].update(key_prefix='trustedCaller.ios.pro')]:
            data = deepcopy(self.data);mutate(data)
            with self.assertRaises(InviteConfigurationError):validate_schema(data)

    def test_install_validation_failure_has_no_device_or_install_side_effect(self):
        with patch.object(INSTALL, 'validate_package', side_effect=InviteConfigurationError('synthetic')), patch(
                'subprocess.run') as run:
            with self.assertRaises(InviteConfigurationError):INSTALL.install(self.options())
            run.assert_not_called()

    def test_verify_only_checks_wired_device_and_never_installs_or_launches(self):
        def device(args, **_):
            output = Path(args[args.index('--json-output') + 1])
            output.write_text(json.dumps({'result': {'connectionProperties': {'transportType': 'wired'}}}))
        with patch.object(INSTALL, 'validate_package', return_value=self.data), patch(
                'subprocess.run', side_effect=device) as run:
            INSTALL.install(self.options(launch=True));self.assertEqual(run.call_count, 1)
            self.assertNotIn('install', run.call_args.args[0])

    def test_wireless_device_stops_before_install(self):
        def device(args, **_):
            Path(args[args.index('--json-output') + 1]).write_text(json.dumps(
                {'result': {'connectionProperties': {'transportType': 'wifi'}}}))
        with patch.object(INSTALL, 'validate_package', return_value=self.data), patch(
                'subprocess.run', side_effect=device) as run:
            with self.assertRaises(InviteConfigurationError):INSTALL.install(self.options(verify_only=False))
            self.assertEqual(run.call_count, 1)

    def test_missing_manifest_is_not_synthesized_for_old_package(self):
        self.path.unlink()
        with patch.object(INSTALL, 'validate_package') as validate, patch('subprocess.run') as run:
            with self.assertRaises(InviteConfigurationError):INSTALL.install(self.options())
            validate.assert_not_called();run.assert_not_called()


if __name__ == '__main__':unittest.main()
