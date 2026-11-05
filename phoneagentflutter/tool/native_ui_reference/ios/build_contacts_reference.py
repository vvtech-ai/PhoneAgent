"""Isolated contact presentation from fixed iOS source; never links business IO."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

from fixed_reference_sources import export_fixed, git, list_fixed

ROOT = Path(__file__).resolve().parents[3]
NATIVE = Path('/Users/Eason/Desktop/Git/AIAssistant/iOS')
REVISION = 'bb9ff34966f40a3c2794a9a8b8e935669a9faa12'
SDK = Path('/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter')
SOURCE = Path(__file__).resolve().parent
OUTPUT = ROOT / '.local/ui-reference/ios-contacts'


def run(args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def read(args):
    return run(args, capture_output=True, text=True).stdout.strip()


def extract(destination):
    prefix = git(NATIVE, 'rev-parse', '--show-prefix').decode().strip()
    names = {
        'list': 'PhoneAgent/PhoneAgent/Features/Contacts/AIContactsViewController.m',
        'detail': 'PhoneAgent/PhoneAgent/Features/Contacts/AIContactDetailViewController.m',
        'policy': 'PhoneAgent/PhoneAgent/Core/Domain/Contact/AIContactDirectoryDetailPolicy.m',
    }
    raw = {key: git(NATIVE, 'show', REVISION + ':' + prefix + path) for key, path in names.items()}
    ranges = []

    def section(key, start, end):
        data = raw[key]
        if data.count(start) != 1 or data.count(end) != 1:
            raise ValueError('Fixed presentation range is missing or ambiguous')
        first = data.index(start)
        last = data.index(end, first)
        value = data[first:last]
        ranges.append({'path': names[key], 'start': first, 'end': last,
                       'sha256': hashlib.sha256(value).hexdigest()})
        return value

    def method(key, marker):
        data = raw[key]
        if data.count(marker) != 1:
            raise ValueError('Fixed method is missing or ambiguous')
        first = data.index(marker)
        position = data.index(b'{', first)
        depth = 1
        position += 1
        while depth:
            if data[position:position + 1] == b'{':
                depth += 1
            elif data[position:position + 1] == b'}':
                depth -= 1
            position += 1
        value = data[first:position] + b'\n'
        ranges.append({'path': names[key], 'start': first, 'end': position,
                       'sha256': hashlib.sha256(data[first:position]).hexdigest()})
        return value

    generated = b'// Generated fixed native presentation only; do not edit.\n#import <math.h>\n'
    generated += section('policy', b'NSUInteger const AIContactDirectoryDescriptionMaximumLength',
                         b'NSArray<NSString *> *AIContactDirectoryPrimaryRelationOptions')
    generated += section('policy', b'NSString *AIContactDirectoryTruncatedValue(',
                         b'NSString *AIContactDirectoryNullableTrimmedValue(')
    generated += section('list', b'@interface AIContactsBackgroundView', b'@interface AIContactsRowCell :')
    generated += section('list', b'@interface AIContactsRowCell :', b'@interface AIContactsDisplayRecord')
    generated += raw['list'][raw['list'].index(b'@interface AIContactsRowCell ()'):]
    generated += section('detail', b'@interface AIContactDetailBackgroundView',
                         b'@interface AIContactDetailViewController ()')
    generated += b'''
@interface ContactsDetailReference : UIViewController
@property(nonatomic, copy) NSString *contactName, *phone, *hint, *remarkText;
@property(nonatomic, strong) UILabel *remarkValueLabel;
@property(nonatomic, strong) UIButton *remarkEditButton, *remarkDeleteButton, *remarkRetryButton;
@property(nonatomic, strong) MASConstraint *remarkRetryHeightConstraint;
- (void)applyRemarkValueText:(NSString *)text color:(UIColor *)color;
@end
@implementation ContactsDetailReference
- (void)viewDidLoad { [super viewDidLoad]; [self buildLayout]; }
'''
    generated += section('detail', b'- (void)buildLayout {', b'- (void)reloadSkillOptions {')
    generated += method('detail', b'- (void)applyRemarkValueText:(NSString *)text color:(UIColor *)color {')
    generated += b'@end\n'
    generated += b'''
@interface ContactsListReference : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIRefreshControl *refreshControl;
@property(nonatomic, strong) UIView *emptyStateView;
@property(nonatomic, strong) NSArray *displayContacts;
@property(nonatomic, assign) BOOL authorizationDenied;
@end
@implementation ContactsListReference
'''
    generated += method('list', b'- (void)buildLayout {')
    generated += method('list', b'- (void)updateEmptyState {')
    generated += method('list', b'- (UIView *)emptyStateView {')
    generated += b'@end\n'
    for forbidden in [b'CNContactStore', b'NSURLSession', b'AIContactDirectoryCoordinator',
                      b'AIDeviceIdentityProvider', b'AIHomeConfigService', b'openURL:']:
        if forbidden in generated:
            raise ValueError('Business dependency in derived presentation')
    target = destination / 'GeneratedContactsPresentation.m'
    target.write_bytes(generated)
    return {'revision': REVISION, 'sources': {names[k]: hashlib.sha256(v).hexdigest() for k, v in raw.items()},
            'ranges': ranges, 'generated_sha256': hashlib.sha256(generated).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['native', 'flutter'])
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--large', action='store_true')
    parser.add_argument('--tab-entry', action='store_true')
    parser.add_argument('--android-style', action='store_true')
    parser.add_argument('--permission-dialog', choices=['consent', 'settings'])
    args = parser.parse_args()
    if (args.tab_entry or args.android_style) and args.kind != 'flutter':
        parser.error('Tab entry is Flutter only')
    if args.android_style and not args.tab_entry:
        parser.error('Android style requires tab entry')
    if args.permission_dialog and (args.kind != 'native' or args.tab_entry):
        parser.error('Permission dialog is native only')
    if args.large and args.kind != 'flutter':
        raise SystemExit('Native fixed UIFont does not support the Flutter text-scale fixture')
    devices = json.loads(read(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
    if not any(d['udid'] == args.simulator and d['state'] == 'Booted'
               for runtime, items in devices['devices'].items() if 'iOS' in runtime for d in items):
        raise SystemExit('Explicit booted iOS simulator required')
    version = json.loads(read([SDK / 'bin/flutter', '--version', '--machine']))
    if version['frameworkVersion'] != '3.32.0' or version['dartSdkVersion'] != '3.8.0':
        raise SystemExit('Pinned toolchain required')
    variant = ('-tab-entry' + ('-android' if args.android_style else '')) if args.tab_entry else ('-permission-' + args.permission_dialog if args.permission_dialog else '')
    artifact = args.kind + variant + ('-large' if args.large else '')
    folder = OUTPUT / artifact
    folder.mkdir(parents=True, exist_ok=True)
    app = folder / 'ContactsReference.app'
    app.mkdir(exist_ok=True)
    bundle_id = 'com.vvtech.phoneagent.ui.contacts.' + args.kind + variant.replace('-', '.') + ('.large' if args.large else '')
    info = {'CFBundleIdentifier': bundle_id, 'CFBundleExecutable': 'ReferenceHost',
            'CFBundleName': 'Contacts Reference', 'CFBundleVersion': '1',
            'CFBundleShortVersionString': '1.0', 'CFBundlePackageType': 'APPL',
            'MinimumOSVersion': '15.0', 'UIDeviceFamily': [1], 'LSRequiresIPhoneOS': True,
            'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
            'UILaunchScreen': {}, 'FLTAssetsPath': 'flutter_assets'}
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    platform_sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    host = SOURCE / 'contacts/ContactsReferenceHost.m'
    command = ['xcrun', '--sdk', 'iphonesimulator', 'clang', '-fobjc-arc', '-fmodules',
               '-target', 'arm64-apple-ios15.0-simulator', '-isysroot', platform_sdk,
               '-framework', 'UIKit', '-framework', 'QuartzCore', host, '-o', app / 'ReferenceHost']
    metadata = {'kind': args.kind, 'large': args.large, 'simulator': args.simulator,
                'tab_entry': args.tab_entry, 'android_style': args.android_style, 'permission_dialog': args.permission_dialog,
                'bundle_id': bundle_id, 'host_sha256': hashlib.sha256(host.read_bytes()).hexdigest(),
                'flutter_head': read(['git', '-C', ROOT, 'rev-parse', 'HEAD']),
                'flutter_diff_sha256': hashlib.sha256(git(ROOT, 'diff', '--', 'lib', 'tool')).hexdigest()}
    if args.kind == 'native':
        metadata['derived'] = extract(folder)
        if args.permission_dialog:
            paths = ['PhoneAgent/PhoneAgent/Features/Contacts/AIContactPermissionDialogViewController.' + ext for ext in ['m', 'h']]
            paths += ['PhoneAgent/PhoneAgent/Core/Domain/Contact/AIContactsTabPermissionPolicy.' + ext for ext in ['m', 'h']]
            snapshot_ui = folder / 'permission'
            metadata['permission_sources'] = export_fixed(NATIVE, REVISION, snapshot_ui, paths, ['PhoneAgent/PhoneAgent/Features/Contacts', 'PhoneAgent/PhoneAgent/Core/Domain/Contact'])
            ui_dir = snapshot_ui / 'PhoneAgent/PhoneAgent/Features/Contacts'
            policy_dir = snapshot_ui / 'PhoneAgent/PhoneAgent/Core/Domain/Contact'
            (ui_dir / 'UIViewController+AICommon.h').write_text('// Generated pure modal declarations only.\n#import <UIKit/UIKit.h>\n@interface UIViewController (ContactsReferenceAccessibility)\n- (void)ai_prepareAccessibilityModalWithBackdropView:(UIView *)view;\n- (void)ai_postAccessibilityModalScreenChanged;\n- (void)ai_restoreAccessibilityFocusAfterModalDismissalIfNeeded;\n@end\n')
            command += ['-DCONTACTS_PERMISSION=1', '-I', ui_dir, '-I', policy_dir, ui_dir / 'AIContactPermissionDialogViewController.m', policy_dir / 'AIContactsTabPermissionPolicy.m']
        masonry_dir = 'PhoneAgent/Pods/Masonry/Masonry'
        names = [p for p in list_fixed(NATIVE, REVISION, masonry_dir) if p.endswith('.m')]
        headers = [masonry_dir + '/Masonry.h']
        snapshot = folder / 'fixed'
        metadata['masonry'] = export_fixed(NATIVE, REVISION, snapshot, names + headers, [masonry_dir])
        command += ['-I', folder, '-I', snapshot / 'PhoneAgent/Pods/Masonry',
                    '-I', snapshot / masonry_dir, *[snapshot / p for p in names]]
    else:
        entry = ROOT / ('tool/native_ui_reference/flutter_contacts_tab_reference.dart' if args.tab_entry else 'tool/native_ui_reference/flutter_contacts_flow_reference.dart')
        with (folder / 'assets-build.log').open('w') as log:
            run([SDK / 'bin/flutter', 'build', 'bundle', '--debug', '--no-pub', '--target-platform=ios',
                 '--target=' + str(entry), '--dart-define=UI_CONTACTS_LARGE=' + str(args.large).lower(),
                 '--dart-define=UI_CONTACTS_PLATFORM=' + ('android' if args.android_style else 'ios'),
                 '--asset-dir=' + str(folder / 'flutter_assets')], cwd=ROOT,
                env={**os.environ, 'PUB_HOSTED_URL': 'https://pub.flutter-io.cn'}, stdout=log, stderr=subprocess.STDOUT)
        shutil.copytree(folder / 'flutter_assets', app / 'flutter_assets', dirs_exist_ok=True)
        engine = SDK / 'bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator'
        (app / 'Frameworks').mkdir(exist_ok=True)
        shutil.copytree(engine / 'Flutter.framework', app / 'Frameworks/Flutter.framework', dirs_exist_ok=True)
        command += ['-DCONTACTS_FLUTTER=1', '-F', engine, '-framework', 'Flutter',
                    '-Wl,-rpath,@executable_path/Frameworks']
        metadata['entry_sha256'] = hashlib.sha256(entry.read_bytes()).hexdigest()
    with (folder / 'compile.log').open('w') as log:
        run(command, stdout=log, stderr=subprocess.STDOUT)
    run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    run(['xcrun', 'simctl', 'install', args.simulator, app], capture_output=True)
    print(read(['xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator, bundle_id] + (['--settings'] if args.permission_dialog == 'settings' else [])))
    metadata['compiled'] = True
    (folder / 'metadata.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
