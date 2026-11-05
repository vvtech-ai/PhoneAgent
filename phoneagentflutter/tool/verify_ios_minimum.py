"""Check iOS application, extension and local Pod deployment declarations."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
targets = re.findall(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);', project)
assert targets and set(targets) == {'16.1'}, targets
with (root / 'ios/Flutter/AppFrameworkInfo.plist').open('rb') as source:
    assert plistlib.load(source)['MinimumOSVersion'] == '16.1'
for relative in ['ios/Podfile', 'ios/IdentityCaptureSDK/PhoneAgentIdentityCapture.podspec',
                 'ios/TrustedCallerSDK/PhoneAgentTrustedCaller.podspec']:
    text = (root / relative).read_text()
    assert re.search(r"platform\s*(?:=|:ios,)\s*(?::ios,\s*)?'16\.1'", text), relative
text = (root / 'tool/configure_trusted_notification_extension.rb').read_text()
assert "'IPHONEOS_DEPLOYMENT_TARGET' => '16.1'" in text
assert "new_target(:app_extension, name, :ios, '16.1')" in text
print('iOS16.1 minimum: Runner configurations, framework, local Pods and extension generator passed')
