"""Invalid synthetic host requests cannot touch devices or source repositories."""
import sys
import unittest
from unittest.mock import patch
import build_reference


class ShellLoginReferenceTest(unittest.TestCase):
    def test_login_requires_flutter_shell_before_any_external_read(self):
        for arguments in [
            ['native', '--shell', '--shell-login'],
            ['native', '--shell-login'],
            ['flutter', '--shell-login'],
        ]:
            with self.subTest(arguments=arguments):
                with patch.object(sys, 'argv', [
                    'build_reference.py', *arguments,
                    '--simulator', 'synthetic-device',
                ]), patch.object(build_reference, 'read') as read, \
                        patch.object(build_reference, 'run') as run:
                    with self.assertRaisesRegex(
                        SystemExit, '--shell-login requires Flutter --shell'
                    ):
                        build_reference.main()
                    read.assert_not_called()
                    run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
