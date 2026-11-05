"""Safety checks for extracting the fixed contact UI without native services."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_contacts_reference as reference


class ContactsReferenceSafetyTests(unittest.TestCase):
    def test_extracts_actual_sheets_without_business_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            metadata = reference.extract(Path(directory))
            text = (Path(directory) / 'GeneratedContactsPresentation.m').read_text()
            self.assertEqual(metadata['revision'], reference.REVISION)
            self.assertIn('@implementation AIContactRemarkSheetViewController', text)
            self.assertIn('@implementation AIContactSkillSheetViewController', text)
            self.assertIn('AIContactsRowCell', text)
            self.assertNotIn('AIContactDirectoryCoordinator', text)
            self.assertNotIn('CNContactStore', text)
            self.assertTrue(metadata['ranges'])

    def test_rejects_new_business_dependency_before_emitting_source(self):
        original = reference.git

        def altered(*args):
            raw = original(*args)
            if args[1] == 'show' and 'AIContactDetailViewController.m' in args[-1]:
                raw = raw.replace(b'- (void)viewDidLoad {', b'- (void)viewDidLoad {\n// CNContactStore injected dependency', 1)
            return raw

        with tempfile.TemporaryDirectory() as directory:
            with patch.object(reference, 'git', side_effect=altered):
                with self.assertRaisesRegex(ValueError, 'Business dependency'):
                    reference.extract(Path(directory))
            self.assertFalse((Path(directory) / 'GeneratedContactsPresentation.m').exists())

    def test_entry_options_rejected_before_device_actions(self):
        for options in [
            ['native', '--tab-entry'],
            ['flutter', '--android-style'],
            ['flutter', '--permission-dialog', 'consent'],
        ]:
            with self.subTest(options=options), patch('sys.argv', ['reference', *options, '--simulator', 'synthetic']), patch.object(reference, 'read') as read, patch.object(reference, 'run') as run:
                with self.assertRaises(SystemExit):
                    reference.main()
                read.assert_not_called()
                run.assert_not_called()

    def test_native_large_rejected_before_device_or_install_calls(self):
        with patch('sys.argv', ['reference', 'native', '--large', '--simulator', 'synthetic']):
            with patch.object(reference, 'run') as run:
                with self.assertRaises(SystemExit):
                    reference.main()
                run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
