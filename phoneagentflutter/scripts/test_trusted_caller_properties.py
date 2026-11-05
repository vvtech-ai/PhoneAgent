"""Synthetic Properties grammar and root-only credential source regressions."""
from pathlib import Path
import tempfile
import unittest

from trusted_caller_properties import parse_properties, read_credentials, TrustedConfigurationError


class TrustedPropertiesTest(unittest.TestCase):
    def test_java_separators_escaped_keys_comments_and_duplicates(self):
        text = ' # comment\n ! comment\na = one\nb:two\nc three\na=last\nescaped\\ key\\:=yes\n'
        self.assertEqual(parse_properties(text), {
            'a': 'last', 'b': 'two', 'c': 'three', 'escaped key:': 'yes'})

    def test_java_escape_unicode_and_surrogate_rules(self):
        text = r'key=\ leading\ space\:\=\#\!\\\t\f\u4e2d\u6587\uD83D\uDE00\z'
        self.assertEqual(parse_properties(text)['key'], ' leading space:=#!\\\t\f中文😀z')

    def test_java_continuation_and_trailing_backslash(self):
        self.assertEqual(parse_properties('key=one\\\n  two\\\r\n\tthree\nlast=end\\'),
                         {'key': 'onetwothree', 'last': 'end'})
        self.assertEqual(parse_properties('key=one\\\n #continued\n'), {'key': 'one#continued'})

    def test_malformed_unicode_has_safe_error(self):
        for value in [r'key=synthetic\u12', r'key=synthetic\uXXYY']:
            with self.assertRaises(TrustedConfigurationError) as caught:
                parse_properties(value)
            self.assertNotIn('synthetic', str(caught.exception))

    def test_root_only_environment_selection_and_updates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'local.properties'
            path.write_text(''.join(f'trustedCaller.android.{env}.{field}=synthetic-{env}-{field}\n'
                                   for env in ['dev', 'test', 'pro'] for field in ['appKey', 'appSecret']))
            for env in ['dev', 'test', 'pro', 'dev']:
                self.assertEqual(read_credentials(root, 'android', env)['appKey'], f'synthetic-{env}-appKey')
            path.write_text('trustedCaller.android.test.appKey=new\ntrustedCaller.android.test.appSecret=new\n')
            self.assertEqual(read_credentials(root, 'android', 'test')['appSecret'], 'new')
            with self.assertRaises(TrustedConfigurationError):
                read_credentials(root, 'android', 'dev')

    def test_no_android_cloud_or_parent_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / 'source'
            (root / 'android').mkdir(parents=True)
            for path in [parent / 'local.properties', root / 'android/local.properties']:
                path.write_text('trustedCaller.android.test.appKey=old\ntrustedCaller.android.test.appSecret=old\n')
            with self.assertRaises(TrustedConfigurationError):
                read_credentials(root, 'android', 'test')

    def test_missing_field_invalid_controls_unknown_env_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'local.properties'
            for value in ['', ' ', '\u00a0', '\u0085', '\u2003', r'synthetic\nsecret', r'synthetic\rsecret', r'synthetic\u0000secret']:
                path.write_text('trustedCaller.android.test.appKey=key\ntrustedCaller.android.test.appSecret=' + value)
                with self.assertRaises(TrustedConfigurationError):
                    read_credentials(root, 'android', 'test')
            with self.assertRaises(TrustedConfigurationError):
                read_credentials(root, 'android', '../test')
            other = root / 'other.properties'
            path.rename(other)
            path.symlink_to(other)
            with self.assertRaises(TrustedConfigurationError):
                read_credentials(root, 'android', 'test')

    def test_six_combinations_and_no_cross_platform_or_legacy_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'local.properties'
            entries = {f'trustedCaller.{platform}.{env}.{field}': f'synthetic-{platform}-{env}-{field}'
                       for platform in ['android', 'ios'] for env in ['dev', 'test', 'pro']
                       for field in ['appKey', 'appSecret']}
            path.write_text(''.join(f'{key}={value}\n' for key, value in entries.items()))
            for platform in ['android', 'ios']:
                for env in ['dev', 'test', 'pro']:
                    self.assertEqual(read_credentials(root, platform, env)['appKey'],
                                     f'synthetic-{platform}-{env}-appKey')
            for platform in ['android', 'ios']:
                key = f'trustedCaller.{platform}.test.appSecret'
                path.write_text(''.join(f'{k}={v}\n' for k, v in entries.items() if k != key) +
                                'trustedCaller.test.appSecret=synthetic-legacy\n')
                with self.assertRaises(TrustedConfigurationError):
                    read_credentials(root, platform, 'test')
            with self.assertRaises(TrustedConfigurationError):
                read_credentials(root, '../ios', 'test')


if __name__ == '__main__':
    unittest.main()
