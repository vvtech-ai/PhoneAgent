"""Synthetic Git fixtures: no native app data or credentials."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from fixed_reference_sources import export_fixed


class FixedSourcesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='synthetic-fixed-ui-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Synthetic Test')
        self.git('config', 'user.email', 'synthetic@example.invalid')
        self.ui = self.repo / 'iOS/UI'
        self.ui.mkdir(parents=True)
        (self.ui / 'Card.m').write_text('#import "Card.h"\n// fixed synthetic UI\n')
        (self.ui / 'Card.h').write_text('#import <UIKit/UIKit.h>\n#import "Style.h"\n')
        (self.ui / 'Style.h').write_text('// fixed synthetic style\n')
        (self.ui / 'Unused.h').write_text('// not a compile dependency\n')
        self.git('add', '.')
        self.git('commit', '-qm', '合成固定参考')
        self.fixed = self.git('rev-parse', 'HEAD').strip()

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args],
                              check=True, capture_output=True, text=True).stdout

    def test_subdirectory_exports_fixed_sources_and_only_required_headers(self):
        (self.ui / 'Card.m').write_text('// advanced synthetic UI\n')
        self.git('commit', '-qam', '合成新参考')
        (self.ui / 'Style.h').write_text('// uncommitted synthetic style\n')
        before = self.git('status', '--porcelain')
        snapshot = self.root / 'snapshot'
        hashes = export_fixed(self.repo / 'iOS', self.fixed, snapshot,
                              ['UI/Card.m'], ['UI'])
        self.assertEqual(set(hashes), {'UI/Card.m', 'UI/Card.h', 'UI/Style.h'})
        self.assertEqual((snapshot / 'UI/Card.m').read_text(),
                         '#import "Card.h"\n// fixed synthetic UI\n')
        self.assertEqual((snapshot / 'UI/Style.h').read_text(), '// fixed synthetic style\n')
        self.assertEqual(self.git('status', '--porcelain'), before)
        self.assertEqual((self.ui / 'Card.m').read_text(), '// advanced synthetic UI\n')

    def test_rejects_escape_and_nondeclared_implementation(self):
        for source in ['../outside.m', '/outside.m', 'Other/Account.m', 'UI/secret.json']:
            with self.assertRaises(ValueError):
                export_fixed(self.repo / 'iOS', self.fixed,
                             self.root / 'snapshot', [source], ['UI'])


if __name__ == '__main__':
    unittest.main()
