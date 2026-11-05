"""Lifecycle regressions use synthetic APK/IPA bytes and isolated directories."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_build_workspace import Artifact, OwnedWorkspace, WorkspaceError, run_pipeline


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name).resolve()
        self.local = self.repo / '.local'
        self.local.mkdir()
        self.messages = []
        self.artifacts = [Artifact('output/test.apk', 'Phone_Agent_TEST_1.0.52_45_test_20261019_120000.apk'),
                          Artifact('output/test.ipa', 'Phone_Agent_TEST_1.0.52_45_test_20261019_120000.ipa')]
        self.work = None

    def build(self, workspace):
        self.work = workspace
        (workspace / 'output').mkdir()
        for artifact in self.artifacts:
            (workspace / artifact.source).write_bytes(b'synthetic package ' + artifact.name.encode())

    def run_build(self, build=None, verify=None, artifacts=None):
        return run_pipeline(self.repo, build or self.build, verify or (lambda _: None),
                            self.artifacts if artifacts is None else artifacts, self.messages.append)

    def test_success_cleans_only_owned_directory_and_keeps_all_deliveries(self):
        root_properties = self.repo / 'local.properties'
        root_properties.write_text('synthetic-root-properties')
        protected = ['cloud-dev', 'cloud-test', 'cloud-pro', 'android/signing', 'test-build-other-task']
        for name in protected:
            path = self.local / name
            path.mkdir(parents=True)
            (path / 'sentinel').write_text(name)
        outputs = self.run_build()
        self.assertFalse(self.work.exists())
        self.assertEqual(root_properties.read_text(), 'synthetic-root-properties')
        self.assertEqual(len(outputs), 2)
        for path, _ in outputs:
            self.assertTrue(path.is_file())
            self.assertTrue(path.is_relative_to(self.repo / 'deliveries'))
        for name in protected:
            self.assertEqual((self.local / name / 'sentinel').read_text(), name)

    def test_build_failure_retains_workspace_and_skips_verification(self):
        verified = []
        def fail(path):
            self.build(path)
            raise RuntimeError('synthetic failure')
        with self.assertRaises(RuntimeError):
            self.run_build(build=fail, verify=lambda _: verified.append(True))
        self.assertTrue(self.work.exists())
        self.assertFalse(verified)
        self.assertFalse((self.repo / 'deliveries').exists())

    def test_verification_failure_retains_workspace(self):
        def fail(_):
            raise RuntimeError('synthetic verification failure')
        with self.assertRaises(RuntimeError):
            self.run_build(verify=fail)
        self.assertTrue(self.work.exists())
        self.assertFalse((self.repo / 'deliveries').exists())

    def test_interrupt_retains_workspace(self):
        def interrupt(path):
            self.build(path)
            raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.run_build(build=interrupt)
        self.assertTrue(self.work.exists())

    def test_export_failure_retains_workspace(self):
        with patch('test_build_workspace.shutil.copyfileobj', side_effect=OSError('synthetic')):
            with self.assertRaises(OSError):
                self.run_build()
        self.assertTrue(self.work.exists())

    def test_export_mismatch_retains_workspace(self):
        def wrong_copy(source, destination):
            destination.write(b'corrupted export')
        with patch('test_build_workspace.shutil.copyfileobj', side_effect=wrong_copy):
            with self.assertRaises(WorkspaceError):
                self.run_build()
        self.assertTrue(self.work.exists())
        self.assertFalse(list((self.repo / 'deliveries').rglob('*.apk')))

    def test_artifact_changed_during_verification_is_rejected(self):
        def mutate(workspace):
            (workspace / self.artifacts[0].source).write_bytes(b'changed')
        with self.assertRaises(WorkspaceError):
            self.run_build(verify=mutate)
        self.assertTrue(self.work.exists())

    def test_cleanup_failure_keeps_successful_delivery(self):
        with patch.object(OwnedWorkspace, 'cleanup', side_effect=OSError('synthetic')):
            outputs = self.run_build()
        self.assertEqual(len(outputs), 2)
        self.assertTrue(self.work.exists())
        self.assertTrue(all(path.is_file() for path, _ in outputs))
        self.assertTrue(any('未清理' in message for message in self.messages))

    def test_platform_without_safe_rmtree_keeps_workspace_and_delivery(self):
        with patch('test_build_workspace.shutil.rmtree.avoids_symlink_attacks', False):
            outputs = self.run_build()
        self.assertTrue(self.work.exists())
        self.assertTrue(all(path.is_file() for path, _ in outputs))
        self.assertTrue(any('未清理' in message for message in self.messages))

    def test_second_export_failure_keeps_workspace_and_first_delivery(self):
        original_copy = shutil.copyfileobj
        calls = []
        def copy(source, target):
            calls.append(True)
            if len(calls) == 2:
                raise OSError('synthetic second export failure')
            original_copy(source, target)
        with patch('test_build_workspace.shutil.copyfileobj', side_effect=copy):
            with self.assertRaises(OSError):
                self.run_build()
        self.assertTrue(self.work.exists())
        self.assertEqual(len(list((self.repo / 'deliveries').rglob('*.apk'))), 1)
        self.assertFalse(list((self.repo / 'deliveries').rglob('*.ipa')))

    def test_reject_absolute_parent_and_duplicate_names_before_build(self):
        for items in [[Artifact('/outside.apk', 'a.apk')], [Artifact('../outside.apk', 'a.apk')],
                      [Artifact('a.apk', '../a.apk')], [Artifact('key.keystore', 'a.apk')],
                      [Artifact('a.apk', 'same.apk'), Artifact('b.apk', 'SAME.apk')], []]:
            with self.subTest(items=items), self.assertRaises(WorkspaceError):
                self.run_build(artifacts=items)
        self.assertFalse(list(self.local.glob('test-build-*')))

    def test_manifest_sidecar_exports_with_ipa_and_cleans_together(self):
        self.artifacts = [Artifact('output/test.ipa', 'final.ipa'),
                          Artifact('output/test.ipa.build.json', 'final.ipa.build.json')]
        outputs = self.run_build()
        self.assertEqual({p.name for p, _ in outputs}, {'final.ipa', 'final.ipa.build.json'})
        self.assertFalse(self.work.exists())

    def test_orphan_or_arbitrary_json_rejected_before_build(self):
        for artifact in [Artifact('input.json', 'config.json'),
                         Artifact('output/test.ipa.build.json', 'final.ipa.build.json')]:
            with self.assertRaises(WorkspaceError):
                self.run_build(artifacts=[artifact])
        self.assertIsNone(self.work)

    def test_reject_symlink_artifact_and_delivery_directory(self):
        outside = self.repo / 'outside.apk'
        outside.write_bytes(b'keep outside')
        def linked(workspace):
            self.build(workspace)
            path = workspace / self.artifacts[0].source
            path.unlink()
            path.symlink_to(outside)
        with self.assertRaises(WorkspaceError):
            self.run_build(build=linked)
        self.assertEqual(outside.read_bytes(), b'keep outside')
        external_delivery = self.repo / 'external-deliveries'
        external_delivery.mkdir()
        (self.repo / 'deliveries').symlink_to(external_delivery, target_is_directory=True)
        with self.assertRaises(WorkspaceError):
            self.run_build()
        self.assertTrue(self.work.exists())
        self.assertFalse(list(external_delivery.iterdir()))

    def test_reject_symlink_and_replacement_workspace_before_cleanup(self):
        for symlink in [True, False]:
            with self.subTest(symlink=symlink):
                owned = OwnedWorkspace(self.repo)
                saved = owned.path.with_name(owned.path.name + '-saved')
                owned.path.rename(saved)
                if symlink:
                    owned.path.symlink_to(saved, target_is_directory=True)
                else:
                    owned.path.mkdir()
                with self.assertRaises(WorkspaceError):
                    owned.cleanup()
                self.assertTrue(saved.is_dir())
                self.assertTrue(owned.path.exists())

    def test_reject_linked_local_parent_before_creating_workspace(self):
        other = self.repo / 'other-local'
        self.local.rename(other)
        self.local.symlink_to(other, target_is_directory=True)
        with self.assertRaises(WorkspaceError):
            self.run_build()
        self.assertFalse(list(other.iterdir()))

    def test_missing_or_empty_artifact_keeps_workspace(self):
        for missing in [True, False]:
            def invalid(workspace):
                self.build(workspace)
                path = workspace / self.artifacts[0].source
                if missing:
                    path.unlink()
                else:
                    path.write_bytes(b'')
            with self.subTest(missing=missing), self.assertRaises(WorkspaceError):
                self.run_build(build=invalid)
            self.assertTrue(self.work.exists())

    def test_cli_executes_build_and_verification_without_real_tools(self):
        scripts = self.repo / 'scripts'
        scripts.mkdir()
        for name in ['run-test-build.py', 'test_build_workspace.py', 'ios_invite_config.py']:
            shutil.copyfile(Path(__file__).with_name(name), scripts / name)
        code = "from pathlib import Path; Path('package.apk').write_bytes(b'synthetic'); Path('built').touch()"
        check = "from pathlib import Path; assert Path('built').is_file(); assert Path('package.apk').read_bytes()==b'synthetic'"
        args = [sys.executable, str(scripts / 'run-test-build.py'), '--build-command',
                json.dumps([sys.executable, '-c', code]), '--verify-command',
                json.dumps([sys.executable, '-c', check]), '--artifact',
                json.dumps({'source': 'package.apk', 'name': self.artifacts[0].name})]
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(list(self.local.glob('test-build-*')))
        self.assertEqual(len(list((self.repo / 'deliveries').rglob('*.apk'))), 1)
        args[args.index('--verify-command') + 1] = json.dumps([sys.executable, '-c', 'raise SystemExit(17)'])
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(list(self.local.glob('test-build-*'))), 1)


if __name__ == '__main__':
    unittest.main()
