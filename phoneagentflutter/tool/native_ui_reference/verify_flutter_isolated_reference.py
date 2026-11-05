"""Verify the opt-in Flutter presentation APK before installing it on an AVD."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
aapt = Path(sys.argv[1]).resolve()
output = root / 'build/app/outputs/apk/debug'
metadata = json.loads((output / 'output-metadata.json').read_text())
package = 'com.vvtech.aiassistant.ui.contactstab' if '--contacts-tab' in sys.argv[2:] else 'com.vvtech.aiassistant.ui.flutterreference'
if any(arg != '--contacts-tab' for arg in sys.argv[2:]):
    raise SystemExit('Unknown isolated verification option')
activity = 'com.vvtech.phone_agent.uireference.FlutterUiReferenceActivity'
if metadata['applicationId'] != package or len(metadata['elements']) != 1:
    raise SystemExit('Isolated reference package mismatch')
apk = (output / metadata['elements'][0]['outputFile']).resolve()
if apk.parent != output.resolve() or not apk.is_file():
    raise SystemExit('Invalid isolated APK path')

def dump(kind, *arguments):
    return subprocess.check_output([str(aapt), 'dump', kind, str(apk), *arguments], text=True)

permissions = re.findall(r"name='([^']+)'", dump('permissions'))
if any(name.startswith('android.permission.') for name in permissions):
    raise SystemExit('Presentation APK retained an Android permission')
manifest = dump('xmltree', 'AndroidManifest.xml')
for name in ['com.vvtech.phone_agent.MainActivity',
             'com.vvtech.phone_agent.diagnostics.NativeCrashApplication',
             'com.vvtech.phone_agent.TranslationCallAudioService', 'androidx.core.content.FileProvider']:
    if name in manifest:
        raise SystemExit('Presentation APK retained a business host/component')
if 'android.app.Application' not in manifest or f"launchable-activity: name='{activity}'" not in dump('badging'):
    raise SystemExit('Presentation launcher/application mismatch')
host = root / 'tool/native_ui_reference/flutter_android_ui_host/FlutterUiReferenceActivity.kt'
source = host.read_text()
if 'override fun configureFlutterEngine(flutterEngine: FlutterEngine) {}' not in source:
    raise SystemExit('Presentation host must not register plugins or channels')
report = {
    'applicationId': package, 'activity': activity, 'androidPermissions': [],
    'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
    'hostSourceSha256': hashlib.sha256(host.read_bytes()).hexdigest(),
    'validationScope': 'Package, launcher, manifest permissions/components and source host only; no business or interaction acceptance.',
}
destination = root / '.local/ui-reference/android-trusted-credentials'
destination.mkdir(parents=True, exist_ok=True)
(destination / 'apk-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('Verified isolated Flutter host, launcher and zero Android permissions')
print(apk)
