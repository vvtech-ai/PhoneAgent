"""Synthetic regressions: Android validates root Properties inputs without generating secrets."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import prepare_trusted_caller_credentials as prepare


class CredentialPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        (self.root / '.gitignore').write_text('.local/\nios/TrustedCallerSDK/Generated/\n')
        for env in ['dev', 'test', 'pro']:
            self.save(env)
        (self.root / 'local.properties').write_text(''.join(
            f'trustedCaller.{platform}.{env}.{field}=synthetic-{platform}-{env}-{field}\n'
            for platform in ['android', 'ios'] for env in ['dev', 'test', 'pro']
            for field in ['appKey', 'appSecret']))

    def save(self, env, **fields):
        path = self.root / f'.local/cloud-{env}/device-defines.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        config = {'APP_ENV': 'prod' if env == 'pro' else env, **fields}
        path.write_text(json.dumps(config))
        return path

    def test_three_cloud_environments_without_reference_access_or_writes(self):
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        for env in ['dev', 'test', 'pro']:
            prepare.validate_android(self.root, env)
        after = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        self.assertFalse((self.root / 'android').exists())

    def test_reject_mismatch_unknown_and_missing_without_fallback(self):
        for env in ['dev', 'test', 'pro']:
            path = self.save(env, APP_ENV='wrong')
            with self.assertRaises(ValueError):
                prepare.validate_android(self.root, env)
            path.unlink()
            with self.assertRaises(ValueError):
                prepare.validate_android(self.root, env)
        with self.assertRaises(ValueError):
            prepare.validate_android(self.root, '../dev')

    def test_bad_json_and_credentials_do_not_expose_values(self):
        path = self.root / 'local.properties'
        original = path.read_text()
        for value in ['', '  ', r'synthetic\nsecret', r'synthetic\u0000secret', r'synthetic\uXXYY']:
            path.write_text('trustedCaller.android.test.appKey=synthetic-key\ntrustedCaller.android.test.appSecret=' + value)
            with self.assertRaises(ValueError) as caught:
                prepare.validate_android(self.root, 'test')
            self.assertNotIn('synthetic', str(caught.exception))
        path.write_text(original)
        path = self.save('test')
        for content in ['[]', 'null', '{"synthetic-private": broken']:
            path.write_text(content)
            with self.assertRaises(ValueError) as caught:
                prepare.validate_android(self.root, 'test')
            self.assertNotIn('synthetic', str(caught.exception))

    def test_reject_symlink_file_or_cloud_directory(self):
        path = self.save('test')
        outside = self.root / 'outside.json'
        path.rename(outside)
        path.symlink_to(outside)
        with self.assertRaises(ValueError):
            prepare.validate_android(self.root, 'test')
        path.unlink()
        outside.rename(path)
        directory = path.parent
        directory.rename(self.root / 'outside-cloud')
        directory.symlink_to(self.root / 'outside-cloud', target_is_directory=True)
        with self.assertRaises(ValueError):
            prepare.validate_android(self.root, 'test')

    def test_android_only_cli_preserves_ios_and_legacy_manifest(self):
        tool = self.root / 'tool'
        tool.mkdir()
        target = tool / 'prepare_trusted_caller_credentials.py'
        shutil.copyfile(prepare.__file__, target)
        scripts = self.root / 'scripts'
        scripts.mkdir()
        shutil.copyfile(Path(prepare.__file__).resolve().parents[1] / 'scripts/trusted_caller_properties.py',
                        scripts / 'trusted_caller_properties.py')
        shutil.copyfile(Path(prepare.__file__).resolve().parents[1] / 'scripts/ios_invite_config.py',
                        scripts / 'ios_invite_config.py')
        protected = [self.root / '.local/trusted-caller/credentials.json',
                     self.root / 'ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m']
        for p in protected:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('synthetic-preserved')
        before = {p: p.read_bytes() for p in protected}
        result = subprocess.run([sys.executable, '-B', str(target), '--android-only'],
                                env={**os.environ, 'PHONEAGENT_ANDROID_ENV': 'test'},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, {p: p.read_bytes() for p in protected})
        self.assertNotIn('synthetic', result.stdout + result.stderr)
        self.assertFalse((self.root / 'android').exists())

    def test_ios_generation_selects_one_platform_and_environment_after_switch(self):
        generated = self.root / 'ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m'
        for environment in ['dev', 'test', 'pro', 'dev']:
            prepare.generate_ios(self.root, environment)
            text = generated.read_text()
            self.assertIn(f'return @"synthetic-ios-{environment}-appKey";', text)
            self.assertNotIn('synthetic-android', text)
            for other in {'dev', 'test', 'pro'} - {environment}:
                self.assertNotIn(f'synthetic-ios-{other}', text)
            self.assertIn(f'PHONEAGENT_TRUSTED_SDK_TEST != {0 if environment == "pro" else 1}', text)
        self.assertEqual(generated.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.root / 'android').exists())
        original = generated.read_bytes()
        (self.root / 'local.properties').write_text('trustedCaller.ios.dev.appKey=synthetic-only')
        with self.assertRaises(ValueError):
            prepare.generate_ios(self.root, 'dev')
        self.assertEqual(generated.read_bytes(), original)

    def test_missing_ignore_and_redirected_parent_fail_before_writing(self):
        with self.assertRaises(ValueError):
            prepare.write_private(self.root, 'credentials.json', 'synthetic')
        with tempfile.TemporaryDirectory() as outside:
            shutil.rmtree(self.root / '.local')
            (self.root / '.local').symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError):
                prepare.write_private(self.root, '.local/credentials.json', 'synthetic')
            self.assertFalse((Path(outside) / 'credentials.json').exists())


if __name__ == '__main__':
    unittest.main()
