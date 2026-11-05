#!/usr/bin/env python3
"""Verify project-local vendor bytes without consulting delivery directories."""
import hashlib
import json
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET
from zipfile import ZipFile


def verify(root: Path) -> int:
    manifest = json.loads(
        (root / "ios/TrustedCallerSDK/SDK_MANIFEST.json").read_text()
    )
    files = manifest["files"]
    if len(files) != 53:
        raise ValueError("Unexpected trusted SDK manifest coverage")
    allowed = (
        "ios/TrustedCallerSDK/Vendor/",
        "ios/TrustedCallerSDK/Resources/",
        "android/app/libs/trusted_caller/",
    )
    for relative, digest in files.items():
        path = root / relative
        if not relative.startswith(allowed) or ".." in Path(relative).parts:
            raise ValueError("SDK manifest path outside project vendor directories")
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing or redirected SDK file: {relative}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f"SDK checksum mismatch: {relative}")
    return len(files)


def verify_portrait(root: Path) -> int:
    namespace = "{http://schemas.android.com/apk/res/android}"
    vendor_activities = set()
    for archive in (root / "android/app/libs/trusted_caller").glob("*.aar"):
        with ZipFile(archive) as sdk:
            source = ET.fromstring(sdk.read("AndroidManifest.xml"))
        vendor_activities.update(
            node.get(namespace + "name") for node in source.findall("./application/activity")
        )
    if len(vendor_activities) != 10:
        raise ValueError("Unexpected SDK Activity coverage")
    source = ET.parse(root / "android/app/src/main/AndroidManifest.xml")
    declared = {
        node.get(namespace + "name"): node.get(namespace + "screenOrientation")
        for node in source.findall("./application/activity")
    }
    if any(declared.get(name) != "portrait" for name in vendor_activities):
        raise ValueError("SDK Activity portrait declaration missing")
    info = plistlib.loads((root / "ios/Runner/Info.plist").read_bytes())
    for key in ("UISupportedInterfaceOrientations", "UISupportedInterfaceOrientations~ipad"):
        if info.get(key) != ["UIInterfaceOrientationPortrait"]:
            raise ValueError("iOS portrait declaration mismatch")
    return len(vendor_activities)


if __name__ == "__main__":
    project = Path(__file__).resolve().parents[1]
    count = verify(project)
    activities = verify_portrait(project)
    print(f"Trusted caller project-local SDK: {count} files verified")
    print(f"Trusted SDK portrait declarations: {activities} Android Activities and iOS verified")
