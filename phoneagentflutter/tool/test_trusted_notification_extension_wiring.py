"""Notification extension wiring regression using real, disposable Xcode projects."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_trusted_identity_extension_wiring import ROOT, RUBY, ENV

NAME = 'TrustedCallerNotificationService'
INSPECT = r'''
require 'xcodeproj'; require 'json'
p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
puts JSON.generate({groups:p.main_group.groups.count{|g|g.path=='TrustedCallerNotificationService'},
 targets:p.targets.map{|t|{name:t.name,configs:t.build_configurations.map{|c|[c.name,c.build_settings,c.base_configuration_reference&.real_path&.to_s]},
 sources:t.source_build_phase.files_references.map{|f|f.real_path.to_s},
 resources:t.resources_build_phase.files_references.map{|f|f.real_path.to_s},
 dependencies:t.dependencies.map{|d|d.target&.name},
 embeds:t.copy_files_build_phases.map{|phase|[phase.name,phase.dst_subfolder_spec,phase.files.map{|f|[f.file_ref.path,f.settings]}]}}}})
'''


class NotificationWiringTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='notification-wiring-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path in ['ios/Runner.xcodeproj', 'ios/TrustedIdentityLiveActivity', 'ios/' + NAME]:
            shutil.copytree(ROOT / path, self.root / path)
        (self.root / 'tool').mkdir()
        for path in ['configure_trusted_notification_extension.rb', 'configure_trusted_identity_extension.rb',
                     'trusted_extension_references.rb', 'verify_trusted_extensions.rb']:
            shutil.copy2(ROOT / 'tool' / path, self.root / 'tool' / path)
        self.project = self.root / 'ios/Runner.xcodeproj/project.pbxproj'
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedCallerNotificationService'}
if g.length==1
  duplicate=p.main_group.new_group(nil,'TrustedCallerNotificationService')
  g.first.files.each{|f|duplicate.new_file(f.path)}
end
p.save
''')

    def ruby(self, script):
        return subprocess.check_output([RUBY, '-e', script], cwd=self.root, env=ENV, text=True)

    def wire(self, script='configure_trusted_notification_extension.rb'):
        subprocess.run([RUBY, 'tool/' + script], cwd=self.root, env=ENV, check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def inspect(self):
        return json.loads(self.ruby(INSPECT))

    def test_duplicate_group_preserves_all_build_relationships_and_real_files(self):
        before = self.inspect()
        files = {p: hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in (self.root / 'ios' / NAME).rglob('*') if p.is_file()}
        self.assertEqual(before.pop('groups'), 2)
        self.wire()
        after = self.inspect()
        self.assertEqual(after.pop('groups'), 1)
        self.assertEqual(after, before)
        self.assertEqual(files, {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in files})

    def test_path_only_single_group_is_reused(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedCallerNotificationService'}
g.drop(1).each{|old|old.remove_from_project};g.first.name=nil;p.save
''')
        self.wire()
        self.assertEqual(self.inspect()['groups'], 1)

    def test_active_config_and_duplicate_sources_are_preserved_and_deduplicated(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedCallerNotificationService'}
t=p.targets.find{|x|x.name=='TrustedCallerNotificationService'}
t.build_configurations.each{|c|c.base_configuration_reference=g.last.files.find{|f|f.path=='Extension.xcconfig'}}
t.source_build_phase.add_file_reference(g.last.files.find{|f|f.path=='NotificationService.swift'},false)
p.save
''')
        before = self.inspect()
        self.wire()
        after = self.inspect()
        self.assertEqual(after['groups'], 1)
        for old, new in zip(before['targets'], after['targets']):
            old['sources'] = list(dict.fromkeys(old['sources']))
            self.assertEqual(old, new)

    def test_repeated_and_interleaved_scripts_are_byte_identical(self):
        self.wire()
        first = self.project.read_bytes()
        self.wire('configure_trusted_identity_extension.rb')
        self.wire()
        self.assertEqual(first, self.project.read_bytes())
        self.assertEqual(self.inspect()['groups'], 1)

    def test_renamed_embed_phase_is_preserved_and_verified(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
p.targets.find{|t|t.name=='Runner'}.copy_files_build_phases.find{|x|x.name=='Embed App Extensions'}.name='Embed Foundation Extensions';p.save
''')
        before = self.inspect()['targets']
        self.wire()
        self.assertEqual(self.inspect()['targets'], before)
        self.wire('verify_trusted_extensions.rb')


if __name__ == '__main__':
    unittest.main()
