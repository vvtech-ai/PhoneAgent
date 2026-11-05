"""Real xcodeproj fixture regression; no device, credentials or build side effects."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUBY = os.environ.get('RUBY', 'ruby')
ENV = os.environ.copy()
if not ENV.get('GEM_HOME'):
    roots = [Path('/opt/homebrew/Cellar/cocoapods'), Path('/usr/local/Cellar/cocoapods')]
    gems = sorted(p.parent.parent for root in roots for p in root.glob('*/libexec/gems/xcodeproj-*'))
    if gems:
        ENV['GEM_HOME'] = str(gems[-1])
INSPECT = r'''
require 'xcodeproj'; require 'json'
p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
r=p.targets.find{|t|t.name=='Runner'}
t=p.targets.find{|t|t.name=='TrustedIdentityLiveActivity'}
puts JSON.generate({groups:p.main_group.groups.count{|g|g.real_path.to_s==File.expand_path('ios/TrustedIdentityLiveActivity')},
 targets:p.targets.map(&:name),settings:p.targets.to_h{|x|[x.name,x.build_configurations.to_h{|c|[c.name,c.build_settings]}]},
 configs:t.build_configurations.map{|c|c.base_configuration_reference.real_path.to_s},
 sources:[r,t].map{|x|x.source_build_phase.files_references.map{|f|f.real_path.to_s}},
 resources:t.resources_build_phase.files_references.map{|f|f.real_path.to_s},
 embeds:r.copy_files_build_phases.select{|x|x.files_references.include?(t.product_reference)}.map{|x|[x.name,x.files_references.map(&:path)]}})
'''


class WiringTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='liveactivity-wiring-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / 'ios/Runner.xcodeproj', self.root / 'ios/Runner.xcodeproj')
        shutil.copytree(ROOT / 'ios/TrustedIdentityLiveActivity', self.root / 'ios/TrustedIdentityLiveActivity')
        shutil.copytree(ROOT / 'ios/TrustedCallerNotificationService', self.root / 'ios/TrustedCallerNotificationService')
        (self.root / 'tool').mkdir()
        for name in ['configure_trusted_identity_extension.rb', 'trusted_extension_references.rb', 'verify_trusted_extensions.rb']:
            if (ROOT / 'tool' / name).exists():
                shutil.copy2(ROOT / 'tool' / name, self.root / 'tool' / name)
        self.project = self.root / 'ios/Runner.xcodeproj/project.pbxproj'
        # Recreate the historical duplicate even after the checked-in project is repaired.
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedIdentityLiveActivity'}
if g.length == 1
  duplicate=p.main_group.new_group('TrustedIdentityLiveActivity','TrustedIdentityLiveActivity')
  g.first.files.each{|f|duplicate.new_file(f.path)}
end
p.save
''')

    def ruby(self, text):
        return subprocess.check_output([RUBY, '-e', text], cwd=self.root, env=ENV, text=True)

    def inspect(self):
        return json.loads(self.ruby(INSPECT))

    def wire(self):
        subprocess.run([RUBY, 'tool/configure_trusted_identity_extension.rb'], cwd=self.root, env=ENV,
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def hashes(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (self.root / 'ios/TrustedIdentityLiveActivity').rglob('*') if p.is_file()}

    def test_duplicate_groups_merge_without_business_settings_or_files_changing(self):
        before, hashes = self.inspect(), self.hashes()
        self.assertEqual(before['groups'], 2)
        self.wire()
        after = self.inspect()
        self.assertEqual(after['groups'], 1)
        self.assertEqual(before['targets'], after['targets'])
        self.assertEqual(before['settings'], after['settings'])
        self.assertEqual(before['configs'], after['configs'])
        self.assertEqual(before['sources'], after['sources'])
        self.assertEqual(len(after['resources']), 1)
        self.assertEqual(before['embeds'], after['embeds'])
        self.assertEqual(hashes, self.hashes())

    def test_active_duplicate_references_and_resources_are_rewired(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedIdentityLiveActivity'}
t=p.targets.find{|x|x.name=='TrustedIdentityLiveActivity'}
t.build_configurations.each{|c|c.base_configuration_reference=g.last.files.find{|f|f.path=='Extension.xcconfig'}}
source=t.source_build_phase.files.find{|b|b.file_ref.path=='TrustedIdentityLiveActivity.swift'}
source.file_ref=g.last.files.find{|f|f.path=='TrustedIdentityLiveActivity.swift'}
t.resources_build_phase.add_file_reference(g.last.files.find{|f|f.path=='Assets.xcassets'},false)
p.save
''')
        before = self.inspect()
        self.assertEqual(len(before['resources']), 2)
        self.wire()
        after = self.inspect()
        self.assertEqual(after['configs'], before['configs'])
        self.assertEqual(after['sources'], before['sources'])
        self.assertEqual(len(after['resources']), 1)
        self.assertEqual(after['groups'], 1)

    def test_second_execution_is_byte_identical(self):
        self.wire()
        first = self.project.read_bytes()
        self.wire()
        self.assertEqual(first, self.project.read_bytes())
        self.assertEqual(self.inspect()['groups'], 1)

    def test_path_only_existing_group_is_reused(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
g=p.main_group.groups.select{|x|x.path=='TrustedIdentityLiveActivity'}
g.drop(1).each{|old|old.children.to_a.dup.each{|f|f.move(g.first)};old.remove_from_project}
g.first.name=nil;p.save
''')
        self.wire()
        self.assertEqual(self.inspect()['groups'], 1)

    def test_renamed_embed_phase_is_preserved(self):
        self.ruby(r'''
require 'xcodeproj'; p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
p.targets.find{|t|t.name=='Runner'}.copy_files_build_phases.find{|x|x.name=='Embed App Extensions'}.name='Embed Foundation Extensions';p.save
''')
        before = self.inspect()['embeds']
        self.wire()
        self.assertEqual(self.inspect()['embeds'], before)
        subprocess.run([RUBY, 'tool/verify_trusted_extensions.rb'], cwd=self.root, env=ENV,
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


if __name__ == '__main__':
    unittest.main()
