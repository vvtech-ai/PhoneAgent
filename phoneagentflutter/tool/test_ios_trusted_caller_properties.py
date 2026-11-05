"""iOS environment/build gates and actual Objective-C compilation, synthetic only."""
import base64
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import prepare_trusted_caller_credentials as prepare


def encoded(environment):
    return base64.b64encode(f'APP_ENV={environment}'.encode()).decode()


class IosTrustedPropertiesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        (self.root / '.gitignore').write_text('local.properties\nios/TrustedCallerSDK/Generated/\n')
        self.properties = self.root / 'local.properties'
        self.properties.write_text(''.join(
            f'trustedCaller.ios.{env}.{field}=synthetic-{env}-{field}\n'
            for env in ['dev', 'test', 'pro'] for field in ['appKey', 'appSecret']))

    def settings(self, environment):
        return {'PHONEAGENT_IOS_ENV': environment, 'DART_DEFINES': encoded(environment),
                'PHONEAGENT_TRUSTED_SDK_ENV': 'pro' if environment == 'prod' else 'test',
                'CONFIGURATION': 'Release' if environment == 'prod' else 'Debug'}

    def test_all_environments_and_runtime_sdk_conflicts(self):
        for environment in ['dev', 'test', 'prod']:
            settings = self.settings(environment)
            expected = 'pro' if environment == 'prod' else environment
            self.assertEqual(prepare.ios_environment(self.root, settings, build=True), expected)
            for key, value in [('DART_DEFINES', encoded('other')),
                               ('PHONEAGENT_TRUSTED_SDK_ENV', 'wrong'),
                               ('PHONEAGENT_IOS_ENV', 'pro')]:
                with self.assertRaises(ValueError):
                    prepare.ios_environment(self.root, {**settings, key: value}, build=True)
        with self.assertRaises(ValueError):
            prepare.ios_environment(self.root, {**self.settings('dev'), 'CONFIGURATION': 'Release'}, build=True)

    def test_generated_xcconfig_fallback_and_explicit_defines_override(self):
        config = self.root / 'ios/Flutter/Generated.xcconfig'
        config.parent.mkdir(parents=True)
        config.write_text('DART_DEFINES=' + encoded('test') + '\n')
        self.assertEqual(prepare.ios_environment(self.root, {}), 'test')
        settings = self.settings('test')
        del settings['DART_DEFINES']
        self.assertEqual(prepare.ios_environment(self.root, settings, build=True), 'test')
        self.assertEqual(prepare.ios_environment(self.root, self.settings('prod'), build=True), 'pro')
        for content in ['DART_DEFINES=invalid!\n',
                        'DART_DEFINES=' + encoded('test') + ',' + encoded('prod') + '\n',
                        'DART_DEFINES=\nDART_DEFINES=\n']:
            config.write_text(content)
            with self.assertRaises(ValueError):
                prepare.ios_environment(self.root, {})

    def test_missing_defines_only_supports_unsigned_dev(self):
        settings = {**self.settings('dev'), 'DART_DEFINES': '', 'CODE_SIGNING_ALLOWED': 'NO'}
        self.assertEqual(prepare.ios_environment(self.root, settings, build=True), 'dev')
        for changed in [{'CODE_SIGNING_ALLOWED': 'YES'}, {'PHONEAGENT_IOS_ENV': 'test'},
                        {'CONFIGURATION': 'Release'}]:
            with self.assertRaises(ValueError):
                prepare.ios_environment(self.root, {**settings, **changed}, build=True)

    def test_ios_cli_has_no_android_or_reference_dependency_and_refreshes(self):
        project = Path(prepare.__file__).resolve().parents[1]
        for relative in ['tool/prepare_trusted_caller_credentials.py',
                         'scripts/trusted_caller_properties.py', 'scripts/ios_invite_config.py']:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / relative, path)
        for environment in ['dev', 'test', 'prod', 'dev']:
            result = subprocess.run([sys.executable, '-B', str(self.root / 'tool/prepare_trusted_caller_credentials.py'),
                                     '--ios-build'], env={**os.environ, **self.settings(environment)},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('synthetic', result.stdout + result.stderr)
            text = (self.root / 'ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m').read_text()
            selected = 'pro' if environment == 'prod' else environment
            self.assertIn(f'synthetic-{selected}-appKey', text)
        self.properties.unlink()
        result = subprocess.run([sys.executable, '-B', str(self.root / 'tool/prepare_trusted_caller_credentials.py'),
                                 '--ios-only'], env={**os.environ, 'DART_DEFINES': encoded('test'),
                                                     'PHONEAGENT_IOS_ENV': 'test'},
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('synthetic', result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('xcrun'), 'Requires macOS Objective-C compiler')
    def test_selected_values_compile_and_sdk_mismatch_fails(self):
        for environment in ['dev', 'test', 'pro']:
            prepare.generate_ios(self.root, environment)
            generated = self.root / 'ios/TrustedCallerSDK/Generated'
            main = generated / 'main.m'
            main.write_text('#import "TrustedCallerLocalCredentials.h"\n'
                'int main() { @autoreleasepool {\n'
                f'if (![TrustedCallerLocalCredentials.appKey isEqual:@"synthetic-{environment}-appKey"]) return 1;\n'
                f'if (![TrustedCallerLocalCredentials.appSecret isEqual:@"synthetic-{environment}-appSecret"]) return 2;\n'
                'return 0; } }\n')
            command = ['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', str(main),
                       str(generated / 'TrustedCallerLocalCredentials.m'), '-o', str(self.root / 'check')]
            sdk_test = 0 if environment == 'pro' else 1
            result = subprocess.run([*command, f'-DPHONEAGENT_TRUSTED_SDK_TEST={sdk_test}'], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            subprocess.run([str(self.root / 'check')], check=True, capture_output=True)
            result = subprocess.run([*command, f'-DPHONEAGENT_TRUSTED_SDK_TEST={1-sdk_test}'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_identical_generation_keeps_timestamp_and_missing_secret_preserves_file(self):
        prepare.generate_ios(self.root, 'test')
        generated = self.root / 'ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m'
        before = generated.stat().st_mtime_ns
        prepare.generate_ios(self.root, 'test')
        self.assertEqual(before, generated.stat().st_mtime_ns)
        self.properties.write_text('trustedCaller.android.test.appKey=synthetic-other\n'
                                   'trustedCaller.android.test.appSecret=synthetic-other\n'
                                   'trustedCaller.test.appKey=synthetic-legacy\n'
                                   'trustedCaller.test.appSecret=synthetic-legacy\n')
        with self.assertRaises(ValueError):
            prepare.generate_ios(self.root, 'test')
        self.assertEqual(before, generated.stat().st_mtime_ns)


if __name__ == '__main__':
    unittest.main()
