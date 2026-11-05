"""Synthetic-input regressions; never reads real credentials or invokes Flutter."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).with_name('build-task-test-apk.py')
spec = importlib.util.spec_from_file_location('android_build', SOURCE)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class AndroidBuildInputsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.base = self.root / '.local'
        (self.base / 'cloud-test').mkdir(parents=True)
        (self.base / 'android/signing').mkdir(parents=True)
        self.config = {'APP_ENV': 'test', **{k: 'synthetic' for k in [
            'SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET']}}
        for key, route in [('API_BASE_URL', 'aiassistant-api'),
                           ('SDK_API_BASE_URL', 'aiassistant-sdk-api'),
                           ('RUNTIME_API_BASE_URL', 'aiassistant-runtime')]:
            self.config[key] = f'https://chakenai-test.vvtech.tech/{route}/'
        self.save()
        (self.root / 'local.properties').write_text(
            'trustedCaller.android.test.appKey=synthetic-key\ntrustedCaller.android.test.appSecret=synthetic-secret\n')
        (self.base / 'android/signing/signing.properties').write_text(
            'signingStoreFile=registered.keystore\nsigningKeyAlias=synthetic\n'
            'signingStorePassword=synthetic\nsigningKeyPassword=synthetic\n')
        (self.base / 'android/signing/registered.keystore').write_bytes(b'synthetic')

    def save(self):
        (self.base / 'cloud-test/device-defines.json').write_text(json.dumps(self.config))

    def test_default_release_and_explicit_debug(self):
        signing, args = build.build_arguments(self.root, 45, 'release')
        self.assertEqual(signing, self.base / 'android/signing/signing.properties')
        for arg in ['--release', '--pub', 'android-arm64', '--build-name=1.0.53',
                    '--build-number=45', 'lib/main.dart']:
            self.assertIn(arg, args)
        self.assertIn(f'--dart-define-from-file={self.base / "cloud-test/device-defines.json"}', args)
        self.assertFalse((self.base / 'android/config').exists())
        self.assertIn('--debug', build.build_arguments(self.root, 45, 'debug')[1])

    def test_reject_each_missing_input(self):
        for name in ['cloud-test/device-defines.json', 'android/signing/signing.properties', 'android/signing/registered.keystore']:
            with self.subTest(name=name):
                path = self.base / name
                data = path.read_bytes()
                path.unlink()
                with self.assertRaises(build.BuildInputError):
                    build.build_arguments(self.root, 45, 'release')
                path.write_bytes(data)

    def test_does_not_fall_back_to_removed_config_directory(self):
        old = self.base / 'android/config/test.json'
        old.parent.mkdir()
        old.write_text(json.dumps(self.config))
        (self.base / 'cloud-test/device-defines.json').unlink()
        with self.assertRaises(build.BuildInputError):
            build.build_arguments(self.root, 45, 'release')

    def test_reject_environment_url_and_missing_credentials(self):
        for key in self.config:
            with self.subTest(key=key):
                old = self.config[key]
                self.config[key] = 'invalid'
                if key.endswith(('KEY', 'SECRET')):
                    self.config[key] = ''
                self.save()
                with self.assertRaises(build.BuildInputError):
                    build.build_arguments(self.root, 45, 'release')
                self.config[key] = old

    def test_reject_external_store_path_and_incomplete_properties(self):
        path = self.base / 'android/signing/signing.properties'
        original = path.read_text()
        for text in [original.replace('registered.keystore', '/tmp/external.keystore'),
                     original.replace('signingKeyPassword=synthetic', '')]:
            path.write_text(text)
            with self.assertRaises(build.BuildInputError):
                build.build_arguments(self.root, 45, 'release')

    def test_root_properties_missing_invalid_and_no_cloud_fallback(self):
        path = self.root / 'local.properties'
        self.config.update(TRUSTED_CALLER_APP_KEY='synthetic-old', TRUSTED_CALLER_APP_SECRET='synthetic-old')
        self.save()
        path.unlink()
        with self.assertRaises(build.BuildInputError):
            build.build_arguments(self.root, 45, 'release')
        for value in ['', '  ', r'synthetic\nsecret', r'synthetic\rsecret', r'synthetic\u0000secret', r'synthetic\uXXYY']:
            path.write_text('trustedCaller.android.test.appKey=synthetic-key\ntrustedCaller.android.test.appSecret=' + value)
            with self.assertRaises(build.BuildInputError) as caught:
                build.build_arguments(self.root, 45, 'release')
            self.assertNotIn('synthetic', str(caught.exception))

    def test_invalid_json_errors_do_not_expose_private_contents(self):
        path = self.base / 'cloud-test/device-defines.json'
        for contents in ['[]', 'null', '{"synthetic-private": broken']:
            path.write_text(contents)
            with self.assertRaises(build.BuildInputError) as caught:
                build.build_arguments(self.root, 45, 'release')
            self.assertNotIn('synthetic', str(caught.exception))

    def test_reject_symlink_file_or_private_root(self):
        path = self.base / 'android/signing/registered.keystore'
        outside = self.root / 'outside.keystore'
        path.rename(outside)
        path.symlink_to(outside)
        with self.assertRaises(build.BuildInputError):
            build.build_arguments(self.root, 45, 'release')
        path.unlink()
        outside.rename(path)
        other = self.root / 'other'
        self.base.rename(other)
        self.base.symlink_to(other, target_is_directory=True)
        with self.assertRaises(build.BuildInputError):
            build.build_arguments(self.root, 45, 'release')

    def test_fake_build_environment_and_exit_status(self):
        scripts = self.root / 'scripts'
        scripts.mkdir()
        target = scripts / SOURCE.name
        shutil.copyfile(SOURCE, target)
        shutil.copyfile(SOURCE.with_name('trusted_caller_properties.py'), scripts / 'trusted_caller_properties.py')
        java = self.root / 'jdk/bin/java'
        java.parent.mkdir(parents=True)
        java.write_text('#!/bin/sh\necho \'openjdk version "17.0.1"\' >&2\n')
        java.chmod(0o700)
        flutter = self.root / 'flutter'
        flutter.write_text('''#!/usr/bin/env python3
import json,os,sys
if '--version' in sys.argv:
    print(json.dumps({'frameworkVersion':'3.32.0'})); sys.exit(0)
assert os.environ['PHONEAGENT_ANDROID_ENV']=='test'
assert os.environ['PHONEAGENT_TEST_SIGNING_PROPERTIES'].endswith('/.local/android/signing/signing.properties')
assert '--release' in sys.argv and '--pub' in sys.argv
from pathlib import Path
assert json.loads((Path(os.environ['XDG_CONFIG_HOME'])/'settings').read_text())['jdk-dir']==os.environ['JAVA_HOME']
sys.exit(int(os.environ['FAKE_EXIT']))
''')
        flutter.chmod(0o700)
        for code in [0, 17]:
            env = {**os.environ, 'FLUTTER': str(flutter), 'JAVA_HOME': str(java.parent.parent),
                   'FAKE_EXIT': str(code), 'PHONEAGENT_ANDROID_ENV': 'prior',
                   'PHONEAGENT_TEST_SIGNING_PROPERTIES': 'prior-path'}
            result = subprocess.run([sys.executable, str(target), '--build-number', '45'],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, code, result.stderr)
            self.assertEqual(env['PHONEAGENT_ANDROID_ENV'], 'prior')
            self.assertEqual(env['PHONEAGENT_TEST_SIGNING_PROPERTIES'], 'prior-path')
            self.assertNotIn('synthetic', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
