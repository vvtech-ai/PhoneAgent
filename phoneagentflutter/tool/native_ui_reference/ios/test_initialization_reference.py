"""Synthetic range and rejection checks; no account, SDK or device fixtures."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import build_initialization_reference as builder
import derive_initialization_presentation as extractor


def synthetic_source():
    sections = []
    for name, start, end in extractor.MARKERS:
        sections.append(start + '\n// synthetic pure ' + name + '\n' + end + '\n')
    return ('// AIAccountSettingsService outside extracted ranges\n' + '\n'.join(sections)).encode()


class InitializationReferenceTest(unittest.TestCase):
    def extract(self, raw, output):
        with patch.object(extractor, 'git', side_effect=[b'iOS/\n', raw]):
            return extractor.extract_initialization_presentation('synthetic', 'fixed', output)

    def test_ranges_keep_exact_bytes_and_hashes_without_outer_services(self):
        raw = synthetic_source()
        with tempfile.TemporaryDirectory() as directory:
            result = self.extract(raw, directory)
            source = (Path(directory) / 'GeneratedInitializationPresentation.m').read_bytes()
            self.assertEqual(len(result['ranges']), 4)
            self.assertTrue(result['original_path'].startswith('iOS/'))
            for value in result['ranges'].values():
                body = raw[value['start']:value['end']]
                self.assertIn(body, source)
                self.assertEqual(hashlib.sha256(body).hexdigest(), value['sha256'])
            self.assertNotIn(b'AIAccountSettingsService', source)
            for name, expected in result['generated_sha256'].items():
                self.assertEqual(hashlib.sha256((Path(directory) / name).read_bytes()).hexdigest(), expected)

    def test_duplicate_marker_is_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'unused'
            with self.assertRaisesRegex(ValueError, 'marker is not unique'):
                self.extract(synthetic_source() + extractor.MARKERS[0][1].encode(), output)
            self.assertFalse(output.exists())

    def test_business_dependency_inside_display_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'unused'
            raw = synthetic_source().replace(b'// synthetic pure cards', b'AIAccountSettingsService')
            with self.assertRaisesRegex(ValueError, 'Business dependency'):
                self.extract(raw, output)
            self.assertFalse(output.exists())

    def test_invalid_device_is_rejected_before_external_read(self):
        for value in ['synthetic-device', '', '../']:
            with self.subTest(value=value), patch.object(sys, 'argv', ['build', '--simulator', value]), \
                    patch.object(builder, 'read') as read, patch.object(builder, 'run') as run:
                with self.assertRaisesRegex(SystemExit, 'UUID'):
                    builder.main()
                read.assert_not_called()
                run.assert_not_called()

    def test_unbooted_device_is_rejected_before_source_or_build(self):
        value = '00000000-0000-0000-0000-000000000000'
        with patch.object(sys, 'argv', ['build', '--simulator', value]), \
                patch.object(builder, 'read', return_value='{"devices": {}}') as read, \
                patch.object(builder, 'run') as run, patch.object(builder, 'extract_initialization_presentation') as extract:
            with self.assertRaisesRegex(SystemExit, 'must be booted'):
                builder.main()
            read.assert_called_once()
            run.assert_not_called()
            extract.assert_not_called()


if __name__ == '__main__':
    unittest.main()
