"""Run the real Gradle input script against synthetic Properties and business JSON and Android DSL objects."""
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from trusted_caller_properties import read_credentials
JAVA_HOME = Path(os.environ.get('JAVA_HOME', '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home'))
GRADLE_HOME = Path(os.environ['GRADLE_HOME']) if 'GRADLE_HOME' in os.environ else next(
    (Path.home() / '.gradle/wrapper/dists').glob('gradle-8.12-*/*/gradle-8.12'), None)


@unittest.skipUnless(GRADLE_HOME and (JAVA_HOME / 'bin/java').is_file(), 'Requires JDK17 and cached Gradle 8.12')
class TrustedCloudGradleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.credentials = {}
        for env in ['dev', 'test', 'pro']:
            self.save(env)

    def save(self, env, **fields):
        path = self.root / f'.local/cloud-{env}/device-defines.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        for field, key in [('appKey', 'TRUSTED_CALLER_APP_KEY'), ('appSecret', 'TRUSTED_CALLER_APP_SECRET')]:
            self.credentials[f'trustedCaller.android.{env}.{field}'] = fields.pop(key, f'synthetic-{env}-{field}')
        def escape(value):
            return value.replace('\\', '\\\\').replace('\n', r'\n').replace('\r', r'\r').replace('\0', r'\u0000').replace(' ', r'\ ')
        (self.root / 'local.properties').write_text(''.join(
            key + '=' + escape(value) + '\n' for key, value in self.credentials.items() if value is not None))
        config = {'APP_ENV': 'prod' if env == 'pro' else env, **fields}
        path.write_text(json.dumps(config))
        return path

    def evaluate(self, env='test', dart_env=None):
        defines = base64.b64encode(f'APP_ENV={dart_env}'.encode()).decode() if dart_env else ''
        result = subprocess.run([
            str(JAVA_HOME / 'bin/java'), '-cp', str(GRADLE_HOME / 'lib/*'),
            'groovy.ui.GroovyMain', str(ROOT / 'tool/trusted_caller_gradle_harness.groovy'),
            str(self.root), str(ROOT / 'android/trusted-caller.gradle'), defines,
        ], env={**os.environ, 'PHONEAGENT_ANDROID_ENV': env}, capture_output=True, text=True)
        return result

    def rejected(self, result):
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('synthetic', result.stdout + result.stderr)
        self.assertNotIn('Exception', result.stderr)  # No parser cause or stack trace.

    def test_environment_selection_and_changed_credentials(self):
        for env in ['test', 'dev', 'pro', 'test']:
            result = self.evaluate(env, 'prod' if env == 'pro' else env)
            self.assertEqual(result.returncode, 0, result.stderr)
            fields = json.loads(result.stdout)
            self.assertEqual(fields['TRUSTED_CALLER_APP_KEY'], f'synthetic-{env}-appKey')
            self.assertEqual(fields['TRUSTED_CALLER_ENVIRONMENT'], 'pro' if env == 'pro' else 'test')
        changed = 'synthetic-new-quote"-slash\\-dollar$-中文'
        self.save('test', TRUSTED_CALLER_APP_SECRET=changed)
        self.assertEqual(json.loads(self.evaluate().stdout)['TRUSTED_CALLER_APP_SECRET'], changed)

    def test_missing_file_does_not_fall_back(self):
        self.save('test').write_text(json.dumps({'APP_ENV': 'test',
            'TRUSTED_CALLER_APP_KEY': 'synthetic-legacy', 'TRUSTED_CALLER_APP_SECRET': 'synthetic-legacy'}))
        (self.root / 'local.properties').unlink()
        self.rejected(self.evaluate())

    def test_ios_and_legacy_fields_never_supply_android_credentials(self):
        path = self.root / 'local.properties'
        original = path.read_text()
        decoys = ('trustedCaller.ios.test.appKey=synthetic-ios-key\n'
                  'trustedCaller.ios.test.appSecret=synthetic-ios-secret\n'
                  'trustedCaller.test.appKey=synthetic-legacy-key\n'
                  'trustedCaller.test.appSecret=synthetic-legacy-secret\n')
        path.write_text(original + decoys)
        result = self.evaluate('test', 'test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['TRUSTED_CALLER_APP_KEY'], 'synthetic-test-appKey')
        path.write_text(decoys)
        self.rejected(self.evaluate('test', 'test'))

    def test_java_and_python_properties_decode_identically(self):
        path = self.root / 'local.properties'
        path.write_text('# comment\n! comment\n' +
            'trustedCaller.android.test.appKey : synthetic-key\n' +
            r'trustedCaller.android.test.appSecret=\ leading\ space\:\=\#\!\\\t\f\u4e2d\u6587\uD83D\uDE00\z' + '\n')
        result = self.evaluate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['TRUSTED_CALLER_APP_SECRET'],
                         read_credentials(self.root, 'android', 'test')['appSecret'])
        path.write_text('trustedCaller.android.test.appKey=synthetic\\\n  continued\n' +
                        'trustedCaller.android.test.appSecret=first\ntrustedCaller.android.test.appSecret=last\\')
        result = self.evaluate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['TRUSTED_CALLER_APP_KEY'],
                         read_credentials(self.root, 'android', 'test')['appKey'])
        self.assertEqual(json.loads(result.stdout)['TRUSTED_CALLER_APP_SECRET'],
                         read_credentials(self.root, 'android', 'test')['appSecret'])

    def test_malformed_properties_is_redacted(self):
        (self.root / 'local.properties').write_text(r'trustedCaller.android.test.appKey=synthetic\uXXYY')
        self.rejected(self.evaluate())

    def test_invalid_json_is_redacted(self):
        for content in ['{"synthetic-private": broken', '[]', 'null']:
            self.save('test').write_text(content)
            self.rejected(self.evaluate())

    def test_invalid_credentials_are_redacted(self):
        for value in [None, '', ' ', '\u00a0', '\u0085', '\u2003', 'synthetic\nsecret', 'synthetic\rsecret', 'synthetic\0secret']:
            self.save('test', TRUSTED_CALLER_APP_SECRET=value)
            self.rejected(self.evaluate())

    def test_environment_and_dart_conflicts(self):
        self.save('pro', APP_ENV='test')
        self.rejected(self.evaluate('pro'))
        self.rejected(self.evaluate('test', 'dev'))
        self.rejected(self.evaluate('../test'))

    def test_redirected_file_and_cloud_parent(self):
        self.save('test')
        path = self.root / 'local.properties'
        other = self.root / 'other.properties'
        path.rename(other)
        path.symlink_to(other)
        self.rejected(self.evaluate())
        path.unlink()
        other.rename(path)
        directory = self.root / '.local/cloud-test'
        directory.rename(self.root / 'other-cloud')
        directory.symlink_to(self.root / 'other-cloud', target_is_directory=True)
        self.rejected(self.evaluate())


if __name__ == '__main__':
    unittest.main()
