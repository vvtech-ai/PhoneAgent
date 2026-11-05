import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import derive_original_audio_presentation as presentation
from build_reference import HEAD, NATIVE
from fixed_reference_sources import git


class OriginalAudioReferenceTests(unittest.TestCase):
    def test_fixed_ranges_and_memory_only_source(self):
        with tempfile.TemporaryDirectory() as directory:
            result = presentation.extract_original_audio_presentation(NATIVE, HEAD, directory)
            generated = Path(directory, 'GeneratedOriginalAudioPresentation.m').read_bytes()
            self.assertIn(b'static BOOL referenceEnabled = YES;', generated)
            self.assertIn(b'referenceVolume = 100, referenceGain = 50', generated)
            self.assertIn(b'popViewControllerAnimated:YES', generated)
            for forbidden in [b'NSUserDefaults', b'KXSDK', b'NSURL', b'AIAccount', b'AVAudio']:
                self.assertNotIn(forbidden, generated)
            for value in result['ranges'].values():
                raw = git(NATIVE, 'show', HEAD + ':' + value['path'])
                section = raw[value['start']:value['end']]
                self.assertIn(section, generated)
                self.assertEqual(hashlib.sha256(section).hexdigest(), value['sha256'])
            for name, digest in result['generated_sha256'].items():
                self.assertEqual(hashlib.sha256(Path(directory, name).read_bytes()).hexdigest(), digest)

    def altered_git(self, transform):
        def read(repo, *args):
            value = git(repo, *args)
            if args[0] == 'show' and args[1].endswith(presentation.SETTINGS):
                return transform(value)
            return value
        return read

    def assert_rejected(self, transform, message):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(presentation, 'git', self.altered_git(transform)):
                with self.assertRaisesRegex(ValueError, message):
                    presentation.extract_original_audio_presentation(NATIVE, HEAD, directory)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_duplicate_marker_rejected_before_output(self):
        self.assert_rejected(
            lambda raw: raw + b'\n@interface AISettingsOriginalAudioToggle :',
            'not unique',
        )

    def test_business_dependency_rejected_before_output(self):
        self.assert_rejected(
            lambda raw: raw.replace(
                b'@interface AISettingsOriginalAudioToggle :',
                b'// KXSDK forbidden injected dependency\n@interface AISettingsOriginalAudioToggle :',
            ).replace(b'@implementation AISettingsOriginalAudioToggle\n',
                      b'@implementation AISettingsOriginalAudioToggle\n// KXSDK forbidden\n'),
            'Business dependency',
        )

    def test_reversed_range_rejected_before_output(self):
        marker = b'#pragma mark - Settings Voice Clone Helpers'
        self.assert_rejected(lambda raw: marker + b'\n' + raw.replace(marker, b''), 'reversed')


if __name__ == '__main__':
    unittest.main()
