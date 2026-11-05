"""Verify an isolated native debug reference without printing configuration values."""
import json
from pathlib import Path
import re
import subprocess
import sys

native = Path(sys.argv[1]).resolve()
aapt = Path(sys.argv[2]).resolve()
output = native / 'app/build/outputs/apk/dev/debug'
metadata = json.loads((output / 'output-metadata.json').read_text())
if metadata['applicationId'] != 'com.vvtech.aiassistant.ui.reference':
    raise SystemExit('Reference application id mismatch')
elements = metadata['elements']
if len(elements) != 1:
    raise SystemExit('Expected exactly one reference APK')
apk = (output / elements[0]['outputFile']).resolve()
if apk.parent != output.resolve() or not apk.is_file():
    raise SystemExit('Invalid reference APK path')
config = native / 'app/build/generated/source/buildConfig/dev/debug/com/vvtech/aiassistant/BuildConfig.java'
fields = re.findall(r'public static final String (\w+)\s*=\s*(".*");', config.read_text())
standard = {'APPLICATION_ID', 'BUILD_TYPE', 'FLAVOR', 'VERSION_NAME'}
custom = [(name, value) for name, value in fields if name not in standard and not name.startswith('FLAVOR_')]
if not custom or any(value != '""' for _, value in custom):
    raise SystemExit('Custom String BuildConfig values were not fully cleared')
permissions = subprocess.check_output([str(aapt), 'dump', 'permissions', str(apk)], text=True)
blocked = ['INTERNET', 'RECORD_AUDIO', 'CAMERA', 'CALL_PHONE', 'READ_CONTACTS', 'READ_CALL_LOG', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']
if any(f"name='android.permission.{name}'" in permissions for name in blocked):
    raise SystemExit('Reference retained a business permission')
print(f'Verified isolated package, {len(custom)} cleared custom fields and removed business permissions')
print(apk)
