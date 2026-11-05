"""Check vendor runtime identity and actual DEX definitions, without executing SDK."""
import argparse
import hashlib
import io
import struct
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

RUNTIME_SHA256 = '79948c1ab28536cd6498ad852476390ce962b5423b0351def3a6f4aab6979198'
ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / 'android/app/libs/trusted_caller/runtime/sdk.jar'
REQUIRED = {
    'Lcom/weway/chaken/incallsdk/ChakenIncallSdk;',
    'Lcom/weway/chaken/bean/ChakenNetworkConfig;',
    'Lcom/weway/chaken/bean/ChakenNetworkConfig$Builder;',
    'Lcom/weway/chaken/utils/LogTestUtil;',
}

# Actual external Glide class references in the copied trusted-caller AARs.
REQUIRED.update('Lcom/bumptech/glide/' + name + ';' for name in [
    'Glide', 'RequestBuilder', 'RequestManager', 'load/DataSource',
    'load/Transformation', 'load/engine/DiskCacheStrategy',
    'load/engine/GlideException', 'load/engine/bitmap_recycle/BitmapPool',
    'load/resource/bitmap/BitmapTransformation',
    'load/resource/bitmap/TransformationUtils', 'request/BaseRequestOptions',
    'request/FutureTarget', 'request/RequestListener', 'request/target/Target',
    'request/target/ViewTarget',
])


def dex_definitions(data):
    if not data.startswith(b'dex\n'):
        raise ValueError('Invalid DEX header')
    def u32(offset):
        return struct.unpack_from('<I', data, offset)[0]
    strings_offset, types_offset = u32(60), u32(68)
    def string(index):
        offset = u32(strings_offset + 4 * index)
        while data[offset] & 128:
            offset += 1
        offset += 1
        return data[offset:data.index(b'\0', offset)].decode('utf8', errors='replace')
    return {
        string(u32(types_offset + 4 * u32(u32(100) + 32 * i)))
        for i in range(u32(96))
    }


def verify_manifest(manifest):
    root = ET.parse(manifest).getroot()
    application = root.find('application')
    android = '{http://schemas.android.com/apk/res/android}'
    permissions = {node.get(android + 'name') for node in root.findall('uses-permission')}
    assert 'android.permission.READ_PRECISE_PHONE_STATE' in permissions, 'Vendor permission declaration removed'
    components = {node.get(android + 'name'): node for node in application}
    for name in ['com.weway.chaken.api.impl.PreciseCallReceiver',
                 'com.weway.chaken.incallsdk.PhoneStateReceiver',
                 'com.weway.chaken.incallsdk.utils.SimStateReceiver',
                 'com.weway.chaken.incallsdk.ChakenCallScreeningService']:
        assert name in components and components[name].get(android + 'enabled', 'true') == 'true', f'Disabled vendor component: {name}'
    assert not any(name and name.startswith('com.vvtech.phone_agent.TrustedCaller') for name in components), 'Obsolete role adapters still declared'
    service = components['com.weway.chaken.incallsdk.ChakenCallScreeningService']
    assert service.get(android + 'permission') == 'android.permission.BIND_SCREENING_SERVICE'
    print('PASS: reference vendor receivers and screening service own manifest')


def verify(apk):
    assert hashlib.sha256(RUNTIME.read_bytes()).hexdigest() == RUNTIME_SHA256, 'Runtime identity changed'
    with zipfile.ZipFile(RUNTIME) as jar:
        vendor = {n for n in jar.namelist() if n.endswith('.class')}
    for path in (ROOT / 'android/app/libs').rglob('*.aar'):
        with zipfile.ZipFile(path) as aar:
            for name in aar.namelist():
                if name.endswith('.jar'):
                    with zipfile.ZipFile(io.BytesIO(aar.read(name))) as jar:
                        assert not vendor.intersection(jar.namelist()), f'Duplicate vendor classes: {path.name}'
    counts = dict.fromkeys(REQUIRED, 0)
    with zipfile.ZipFile(apk) as package:
        for name in package.namelist():
            if name.endswith('.dex'):
                definitions = dex_definitions(package.read(name))
                for target in REQUIRED:
                    counts[target] += target in definitions
    assert all(n == 1 for n in counts.values()), f'Missing or duplicate definitions: {counts}'
    print(f'PASS: runtime SHA256, AAR overlap, and {len(REQUIRED)} required APK class definitions (including SDK Glide display dependencies)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--manifest', type=Path, default=ROOT / 'build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml')
    args = parser.parse_args()
    verify(args.apk)
    verify_manifest(args.manifest)
