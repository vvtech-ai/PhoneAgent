#!/usr/bin/env python3
"""Compile isolated simulator hosts from actual UIKit and fixed Flutter sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
from fixed_reference_sources import export_fixed, list_fixed
from derive_history_presentation import extract_history_presentation

ROOT = Path(__file__).resolve().parents[3]
NATIVE = Path('/Users/Eason/Desktop/Git/AIAssistant/iOS')
HEAD = 'bb9ff34966f40a3c2794a9a8b8e935669a9faa12'
SDK = Path('/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter')
SOURCE = Path(__file__).resolve().parent
OUTPUT = ROOT / '.local/ui-reference/ios-isolated'


def run(args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def read(args):
    return run(args, capture_output=True, text=True).stdout.strip()


def info(bundle_id):
    return {
        'CFBundleIdentifier': bundle_id,
        'CFBundleExecutable': 'ReferenceHost',
        'CFBundleName': 'UI Reference',
        'CFBundleVersion': '1',
        'CFBundleShortVersionString': '1.0',
        'CFBundlePackageType': 'APPL',
        'MinimumOSVersion': '15.0',
        'LSRequiresIPhoneOS': True,
        'UIDeviceFamily': [1],
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
        'UILaunchScreen': {},
        'FLTAssetsPath': 'flutter_assets',
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['native', 'flutter'])
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--dynamic', action='store_true')
    parser.add_argument('--short', action='store_true')
    parser.add_argument('--shell', action='store_true')
    parser.add_argument('--shell-login', action='store_true')
    parser.add_argument('--recording-scenario', choices=['normal', 'processing', 'loadFailure', 'playFailure', 'saveFailure'], default='normal')
    parser.add_argument('--batch', action='store_true')
    parser.add_argument('--outbound', action='store_true')
    parser.add_argument('--language', action='store_true')
    parser.add_argument('--record-time', action='store_true')
    parser.add_argument('--history-content', action='store_true')
    parser.add_argument('--history-empty', action='store_true')
    parser.add_argument('--history-initial', choices=['none', 'loading', 'error'], default='none')
    parser.add_argument('--outbound-state', choices=['saved', 'empty', 'loading', 'error'], default='saved')
    parser.add_argument('--result', action='store_true')
    parser.add_argument('--transcript', action='store_true')
    parser.add_argument('--document', action='store_true')
    parser.add_argument('--options', action='store_true')
    parser.add_argument('--options-timeline', action='store_true')
    parser.add_argument('--tasks-scroll', action='store_true')
    parser.add_argument('--trusted-intro', action='store_true')
    parser.add_argument('--trusted-credentials', action='store_true')
    parser.add_argument('--large-text', action='store_true')
    args = parser.parse_args()
    if args.shell_login and not (args.kind == 'flutter' and args.shell):
        raise SystemExit('--shell-login requires Flutter --shell')
    if args.recording_scenario != 'normal' and not (args.kind == 'flutter' and args.shell):
        raise SystemExit('--recording-scenario requires Flutter --shell')
    if args.history_initial != 'none' and (not args.history_content or args.history_empty):
        raise SystemExit('--history-initial requires --history-content and excludes --history-empty')
    if args.history_empty and not args.history_content:
        raise SystemExit('--history-empty requires --history-content')
    if args.history_content and any([
            args.record_time, args.language, args.outbound, args.batch, args.result,
            args.transcript, args.document, args.options, args.options_timeline,
            args.tasks_scroll, args.trusted_intro, args.trusted_credentials,
            args.shell, args.short, args.dynamic]):
        raise SystemExit('--history-content excludes other fixtures')
    if args.record_time and (args.kind != 'flutter' or any([
            args.language, args.outbound, args.batch, args.result, args.transcript,
            args.document, args.options, args.options_timeline, args.tasks_scroll,
            args.trusted_intro, args.trusted_credentials, args.large_text,
            args.shell, args.short, args.dynamic])):
        raise SystemExit('--record-time requires Flutter and excludes other fixtures')
    if args.language and any([args.outbound, args.batch, args.result, args.transcript,
                              args.document, args.options, args.options_timeline,
                              args.tasks_scroll, args.trusted_intro, args.trusted_credentials,
                              args.large_text, args.shell, args.short, args.dynamic]):
        raise SystemExit('--language excludes other fixtures')
    if args.outbound and any([args.language, args.batch, args.result, args.transcript, args.document,
                             args.options, args.options_timeline, args.tasks_scroll,
                             args.trusted_intro, args.trusted_credentials, args.large_text,
                             args.shell, args.short, args.dynamic]):
        raise SystemExit('--outbound excludes other fixtures')
    if not args.outbound and args.outbound_state != 'saved':
        raise SystemExit('--outbound-state requires --outbound')
    if args.large_text and not (args.kind == 'flutter' and (args.trusted_intro or args.trusted_credentials or args.history_content)):
        raise SystemExit('--large-text requires Flutter trusted or history-content fixture')
    if args.trusted_credentials and (args.kind != 'flutter' or any([
            args.trusted_intro, args.tasks_scroll, args.options_timeline, args.options,
            args.document, args.batch, args.result, args.shell, args.short,
            args.dynamic, args.transcript])):
        raise SystemExit('--trusted-credentials requires Flutter and excludes other fixtures')
    if args.trusted_intro and (args.kind != 'flutter' or any([
            args.tasks_scroll, args.options_timeline, args.options, args.document,
            args.batch, args.result, args.shell, args.short, args.dynamic, args.transcript])):
        raise SystemExit('--trusted-intro requires Flutter and excludes other fixtures')
    if args.tasks_scroll and (args.kind != 'flutter' or any([
            args.options_timeline, args.options, args.document, args.batch,
            args.result, args.shell, args.short, args.dynamic, args.transcript])):
        raise SystemExit('--tasks-scroll requires Flutter and excludes other fixtures')
    if args.options_timeline:
        if args.kind != 'flutter' or args.options:
            raise SystemExit('--options-timeline requires Flutter and excludes --options')
        args.options = True
    if args.options and any([args.document, args.batch, args.result, args.shell, args.short, args.dynamic, args.transcript]):
        raise SystemExit('--options excludes other fixtures')
    if args.document and (args.batch or args.result or args.shell or args.short or args.dynamic):
        raise SystemExit('--document excludes other fixtures')
    if args.transcript and not args.result:
        raise SystemExit('--transcript requires --result')
    if args.result and (args.batch or args.shell or args.short or args.dynamic):
        raise SystemExit('--result excludes batch/shell/short/dynamic fixtures')
    if args.batch and (args.shell or args.short or args.dynamic):
        raise SystemExit('--batch excludes shell/short/dynamic fixtures')
    if args.shell and (args.kind != 'flutter' or args.short or args.dynamic):
        raise SystemExit('--shell requires Flutter and excludes short/dynamic fixtures')
    artifact = args.kind + ('-shell' if args.shell else '-batch' if args.batch else '-result' if args.result else '-document' if args.document else '-options' if args.options else '')
    artifact += '-login' if args.shell_login else ''
    artifact += '-recording-' + args.recording_scenario if args.recording_scenario != 'normal' else ''
    artifact += '-history-content' if args.history_content else ''
    artifact += '-empty' if args.history_empty else ''
    artifact += '-initial-' + args.history_initial if args.history_initial != 'none' else ''
    artifact += '-record-time' if args.record_time else ''
    artifact += '-language' if args.language else ''
    artifact += '-outbound-' + args.outbound_state if args.outbound else ''
    artifact += '-timeline' if args.options_timeline else ''
    artifact += '-tasks-scroll' if args.tasks_scroll else ''
    artifact += '-trusted-intro' if args.trusted_intro else ''
    artifact += '-trusted-credentials' if args.trusted_credentials else ''
    artifact += '-large' if args.large_text else ''
    artifact += '-transcript' if args.transcript else ''
    native_worktree_head = read(['git', '-C', NATIVE, 'rev-parse', 'HEAD'])
    devices = json.loads(read(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
    booted = [device for runtime, items in devices['devices'].items()
              if 'iOS' in runtime for device in items
              if device['udid'] == args.simulator and device['state'] == 'Booted']
    if len(booted) != 1:
        raise SystemExit('An explicitly selected booted iOS simulator is required')
    version = json.loads(read([SDK / 'bin/flutter', '--version', '--machine']))
    if version['frameworkVersion'] != '3.32.0' or version['dartSdkVersion'] != '3.8.0':
        raise SystemExit('Reference requires Flutter 3.32.0 / Dart 3.8.0')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bundle_id = 'com.vvtech.phoneagent.ui.ios' + args.kind + ('.shell' if args.shell else '.batch' if args.batch else '.result' if args.result else '.document' if args.document else '.options' if args.options else '')
    bundle_id += '.login' if args.shell_login else ''
    bundle_id += '.recording.' + args.recording_scenario.lower() if args.recording_scenario != 'normal' else ''
    bundle_id += '.historycontent' if args.history_content else ''
    bundle_id += '.empty' if args.history_empty else ''
    bundle_id += '.initial' + args.history_initial if args.history_initial != 'none' else ''
    bundle_id += '.recordtime' if args.record_time else ''
    bundle_id += '.language' if args.language else ''
    bundle_id += '.outbound.' + args.outbound_state if args.outbound else ''
    bundle_id += '.timeline' if args.options_timeline else ''
    bundle_id += '.tasksscroll' if args.tasks_scroll else ''
    bundle_id += '.trustedintro' if args.trusted_intro else ''
    bundle_id += '.trustedcredentials' if args.trusted_credentials else ''
    bundle_id += '.large' if args.large_text else ''
    bundle_id += '.transcript' if args.transcript else ''
    app = OUTPUT / (artifact + '.app')
    if app.exists():
        shutil.rmtree(app)  # Only this managed reference build, never installed App data.
    app.mkdir()
    with (app / 'Info.plist').open('wb') as target:
        plistlib.dump(info(bundle_id), target)
    platform_sdk = read(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    host = (SOURCE / 'history/HistoryContentReferenceHost.m' if args.history_content and args.kind == 'native'
            else SOURCE / 'language/LanguageReferenceHost.m' if args.language and args.kind == 'native'
            else SOURCE / 'outbound/OutboundReferenceHost.m' if args.outbound and args.kind == 'native'
            else SOURCE / 'ReferenceHost.m')
    command = ['xcrun', '--sdk', 'iphonesimulator', 'clang', '-fobjc-arc',
               '-fmodules', '-target', 'arm64-apple-ios15.0-simulator',
               '-isysroot', platform_sdk, '-framework', 'UIKit',
               '-framework', 'Foundation', '-framework', 'QuartzCore', '-framework', 'CoreText',
               '-o', app / 'ReferenceHost', host]
    sources = [host]
    extracted_history = {}
    if args.kind == 'native':
        phone = NATIVE / 'PhoneAgent/PhoneAgent'
        directories = [phone / 'Features/Assistant', phone / 'Core/Utilities',
                       phone / 'Core/Domain/Agent']
        sources += [directories[0] / 'AIPureVoiceBubbleView.m',
                    directories[1] / 'AIInlineMarkdownRenderer.m',
                    directories[2] / 'AIInlineMarkdownPolicy.m']
        if args.history_content:
            directories = [phone / 'Core/Models', phone / 'Core/Domain/Translation']
            sources = [host, directories[0] / 'AIRealtimeTranslationModels.m',
                       directories[0] / 'AISettingsModels.m', directories[0] / 'AIJSONModel.m',
                       directories[1] / 'AITranslationCallRuntimePolicy.m']
        if args.language:
            directories = [phone / 'Features/Calls', phone / 'Core/Domain/Translation']
            sources = [host, directories[0] / 'AITranslationLanguagePickerViewController.m',
                       directories[1] / 'AITranslationDialPresetPolicy.m']
        if args.outbound:
            directories = [phone / 'Features/Settings', phone / 'Core/Domain/Settings']
            sources = [host, directories[0] / 'AISettingsOutboundNumberViewController.m',
                       directories[1] / 'AIOutboundNumberPolicy.m']
            command += ['-I', SOURCE / 'outbound']
        if args.batch or args.result:
            directories += [phone / 'Core/Domain/Points', phone / 'Core/Domain/Task']
            sources += [directories[0] / 'AIBatchTaskConfirmationCardView.m',
                        directories[2] / 'AIBatchTaskConfirmationPolicy.m',
                        directories[2] / 'AIBatchPlusPresentationPolicy.m',
                        directories[3] / 'AIPointsPolicy.m',
                        directories[4] / 'AITaskReceiptContract.m',
                        directories[4] / 'AITaskStatusContract.m']
            if args.result:
                sources += [directories[0] / 'AIBatchCallItemResultView.m',
                            directories[0] / 'AITaskCallBillingSummaryView.m',
                            directories[2] / 'AITaskCallBillingSummaryPresentation.m']
                command += ['-DREFERENCE_RESULT=1']
            else:
                command += ['-DREFERENCE_BATCH=1']
        if args.options:
            sources += [directories[0] / 'AIAgentInteractiveCardView.m',
                        directories[2] / 'AIRestaurantOptionPresentation.m']
            command += ['-DREFERENCE_OPTIONS=1']
        if args.document:
            sources += [directories[0] / 'AILargeTaskDocumentCardView.m',
                        directories[2] / 'AIUserDocumentPolicy.m']
            command += ['-DREFERENCE_DOCUMENT=1']
        masonry = NATIVE / 'PhoneAgent/Pods/Masonry'
        sources += [NATIVE / path for path in list_fixed(
            NATIVE, HEAD, 'PhoneAgent/Pods/Masonry/Masonry') if path.endswith('.m')]
        snapshot = OUTPUT / ('fixed-source-' + HEAD)
        include_dirs = [str(path.relative_to(NATIVE)) for path in [*directories, masonry]]
        fixed_hashes = export_fixed(
            NATIVE, HEAD, snapshot,
            [str(path.relative_to(NATIVE)) for path in sources[1:]], include_dirs)
        sources = [sources[0], *[snapshot / path.relative_to(NATIVE) for path in sources[1:]]]
        for directory in include_dirs:
            command += ['-I', snapshot / directory]
        command += sources[1:]
        if args.history_content:
            generated = OUTPUT / ('fixed-history-presentation-' + HEAD)
            extracted_history = extract_history_presentation(NATIVE, HEAD, generated)
            command += ['-I', generated, generated / 'GeneratedHistoryPresentation.m']
            sources += [generated / 'GeneratedHistoryPresentation.h',
                        generated / 'GeneratedHistoryPresentation.m',
                        SOURCE / 'derive_history_presentation.py',
                        SOURCE / 'history/HistoryFontDiagnostics.h']
    else:
        engine = SDK / 'bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator'
        framework = engine / 'Flutter.framework'
        if not framework.is_dir():
            raise SystemExit('Fixed SDK simulator framework unavailable')
        entry = (ROOT / 'tool/native_ui_reference/flutter_history_content_reference.dart' if args.history_content
                 else ROOT / 'tool/native_ui_reference/flutter_record_time_reference.dart' if args.record_time
                 else ROOT / 'tool/native_ui_reference/flutter_language_reference.dart' if args.language
                 else ROOT / 'tool/native_ui_reference/flutter_outbound_reference.dart' if args.outbound
                 else ROOT / 'tool/native_ui_reference/flutter_trusted_credentials_reference.dart'
                 if args.trusted_credentials else ROOT / 'tool/native_ui_reference/flutter_trusted_introduction_reference.dart'
                 if args.trusted_intro else ROOT / 'tool/ui_consistency_preview.dart' if args.shell
                 else SOURCE / 'flutter_bubble_reference.dart')
        defines = (['ENABLE_MIGRATION_PREVIEWS=false', 'UI_START_SIGNED_IN=' + str(not args.shell_login).lower(),
                    'UI_READ_INSTALLED_METADATA=false', 'UI_FORMAL_CLONE=true',
                    'UI_NATIVE_SYSTEM_VOICES=true', 'UI_AGENT_DOCUMENT=true',
                    'UI_DOCUMENT_PARSE_DELAY_MS=10000',
                    'UI_RECORDING_SCENARIO=' + args.recording_scenario] if args.shell else
                   ['UI_REFERENCE_DYNAMIC=' + str(args.dynamic).lower(),
                    'UI_REFERENCE_SHORT=' + str(args.short).lower(),
                    'UI_REFERENCE_BATCH=' + str(args.batch).lower(),
                    'UI_REFERENCE_RESULT=' + str(args.result).lower(),
                    'UI_REFERENCE_TRANSCRIPT=' + str(args.transcript).lower(),
                    'UI_REFERENCE_DOCUMENT=' + str(args.document).lower(),
                    'UI_REFERENCE_OPTIONS=' + str(args.options).lower(),
                    'UI_REFERENCE_OPTIONS_TIMELINE=' + str(args.options_timeline).lower(),
                    'UI_REFERENCE_TASKS_SCROLL=' + str(args.tasks_scroll).lower(),
                    'UI_REFERENCE_INTRO_LARGE=' + str(args.large_text).lower(),
                    'UI_REFERENCE_CREDENTIALS_LARGE=' + str(args.large_text).lower(),
                    'UI_REFERENCE_HISTORY_LARGE=' + str(args.large_text).lower(),
                    'UI_REFERENCE_HISTORY_EMPTY=' + str(args.history_empty).lower(),
                    'UI_REFERENCE_HISTORY_INITIAL=' + args.history_initial])
        if args.outbound:
            defines += ['UI_REFERENCE_OUTBOUND_STATE=' + args.outbound_state]
        log = OUTPUT / (artifact + '-assets-build.log')
        with log.open('w') as target:
            run([SDK / 'bin/flutter', 'build', 'bundle', '--debug', '--no-pub',
                 '--target-platform=ios',
                 *['--dart-define=' + define for define in defines],
                 '--target=' + str(entry),
                 '--asset-dir=' + str(OUTPUT / 'flutter_assets')],
                cwd=ROOT, stdout=target, stderr=subprocess.STDOUT,
                env={**os.environ, 'PUB_HOSTED_URL': 'https://pub.flutter-io.cn'})
        shutil.copytree(OUTPUT / 'flutter_assets', app / 'flutter_assets', dirs_exist_ok=True)
        (app / 'Frameworks').mkdir(exist_ok=True)
        shutil.copytree(framework, app / 'Frameworks/Flutter.framework', dirs_exist_ok=True)
        paragraph = ROOT / 'ios/Runner/NativeParagraphChannel.swift'
        library = app / 'Frameworks/libNativeParagraph.dylib'
        with (OUTPUT / 'paragraph-swift-compile.log').open('w') as target:
            run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-emit-library',
                 '-module-name', 'PhoneAgentNativeParagraph',
                 '-target', 'arm64-apple-ios15.0-simulator', '-sdk', platform_sdk,
                 '-F', engine, '-framework', 'Flutter', '-framework', 'UIKit',
                 '-Xlinker', '-install_name', '-Xlinker', '@rpath/libNativeParagraph.dylib',
                 '-o', library, paragraph], stdout=target, stderr=subprocess.STDOUT)
        sources += [paragraph]
        command += ['-DREFERENCE_FLUTTER=1', '-F', engine, '-framework', 'Flutter',
                    '-L', app / 'Frameworks', '-lNativeParagraph',
                    '-Wl,-rpath,@executable_path/Frameworks', '-Wl,-rpath,/usr/lib/swift']
        sources += [entry,
                    ROOT / 'lib/features/conversation/presentation/widgets/native_message_paragraph.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/conversation_message_tile.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/native_conversation_text_bubble.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/batch_confirmation_card.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/batch_confirmation_contacts.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/receipts/native_batch_item_header.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/receipts/native_batch_transcript.dart',
                    ROOT / 'lib/features/attachments/presentation/widgets/native_document_card.dart',
                    ROOT / 'tool/native_ui_reference/flutter_options_reference.dart',
                    ROOT / 'tool/native_ui_reference/flutter_options_timeline_reference.dart',
                    ROOT / 'tool/native_ui_reference/flutter_tasks_scroll_reference.dart',
                    ROOT / 'lib/features/tasks/presentation/pages/tasks_page.dart',
                    ROOT / 'lib/features/tasks/presentation/pages/task_record_card.dart',
                    ROOT / 'lib/features/conversation/presentation/pages/conversation_page.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/native_conversation_timeline.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/conversation_content_revision.dart',
                    ROOT / 'lib/features/conversation/domain/conversation_messages.dart',
                    ROOT / 'lib/features/conversation/domain/restaurant_option_presentation.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/conversation_options_card.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/conversation_option_content.dart',
                    ROOT / 'lib/features/conversation/presentation/widgets/conversation_option_values.dart']
    if args.shell:
        sources += [ROOT / 'lib/features/initialization/domain/initialization_gateway.dart',
                    ROOT / 'lib/features/initialization/presentation/pages/initialization_page.dart',
                    ROOT / 'lib/features/initialization/presentation/widgets/initialization_fields.dart',
                    ROOT / 'lib/features/initialization/presentation/widgets/initialization_model_cards.dart',
                    ROOT / 'lib/features/initialization/presentation/widgets/initialization_header.dart',
                    ROOT / 'lib/features/dialer/presentation/pages/dialer_route.dart',
                    ROOT / 'lib/features/dialer/presentation/pages/dial_country_route.dart',
                    ROOT / 'lib/features/translation/presentation/pages/translation_dialer_route.dart',
                    ROOT / 'lib/features/translation/presentation/pages/translation_selection_pages.dart',
                    ROOT / 'lib/features/translation/presentation/pages/translation_settings_route.dart',
                    ROOT / 'lib/features/translation/presentation/widgets/translation_presets.dart',
                    ROOT / 'lib/features/translation/presentation/widgets/translation_model_sheet.dart',
                    ROOT / 'lib/features/translation/presentation/widgets/translation_overseas_settings_entry.dart',
                    ROOT / 'lib/features/translation/presentation/widgets/translation_catalog_status.dart',
                    ROOT / 'lib/core/design/native_setting_controls.dart']
    if args.trusted_intro:
        sources += [ROOT / 'lib/features/trusted_caller/presentation/pages/trusted_caller_introduction_page.dart',
                    ROOT / 'pubspec.yaml',
                    *sorted((ROOT / 'assets/images/trusted_caller').glob('*'))]
    if args.trusted_credentials:
        sources += [ROOT / 'lib/features/trusted_caller/presentation/pages/trusted_identity_credentials_page.dart',
                    ROOT / 'lib/features/trusted_caller/presentation/widgets/trusted_identity_certificate.dart',
                    ROOT / 'lib/features/trusted_caller/presentation/widgets/trusted_identity_time.dart',
                    ROOT / 'lib/features/trusted_caller/domain/trusted_incoming_identity.dart',
                    ROOT / 'pubspec.yaml',
                    *sorted((ROOT / 'assets/images/trusted_identity').glob('*'))]
    with (OUTPUT / (artifact + '-compile.log')).open('w') as target:
        run(command, stdout=target, stderr=subprocess.STDOUT)
    run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    run(['xcrun', 'simctl', 'install', args.simulator, app], capture_output=True)
    # Launch output is only a bundle/PID; runtime logs are not printed.
    print(read(['xcrun', 'simctl', 'launch', '--terminate-running-process',
                '--stdout=' + str(OUTPUT / (artifact + '-runtime.stdout')),
                '--stderr=' + str(OUTPUT / (artifact + '-runtime.stderr')),
                args.simulator, bundle_id,
                *(['--synthetic-long'] if args.kind == 'native' and args.dynamic else []),
                *(['--synthetic-short'] if args.kind == 'native' and args.short else []),
                *(['--synthetic-transcript'] if args.kind == 'native' and args.transcript else []),
                *(['--outbound-state', args.outbound_state] if args.outbound else []),
                *(['--history-empty'] if args.history_empty else []),
                *(['--history-initial', args.history_initial] if args.history_initial != 'none' else [])]))
    if args.outbound:
        sources += [SOURCE / 'outbound/AIAccountSettingsService.h', SOURCE / 'outbound/AISettingsModels.h',
                    ROOT / 'lib/features/settings/presentation/pages/outbound_number_page.dart',
                    ROOT / 'lib/core/design/native_detail_header.dart', ROOT / 'lib/core/design/native_gradient_action.dart']
    if args.language:
        sources += [ROOT / 'lib/features/translation/presentation/pages/translation_selection_pages.dart',
                    ROOT / 'lib/features/translation/domain/translation_preferences.dart']
    if args.record_time:
        sources += [ROOT / 'lib/core/domain/record_time.dart',
                    ROOT / 'lib/features/tasks/presentation/pages/tasks_page.dart',
                    ROOT / 'lib/features/translation_history/presentation/controller/translation_history_controller.dart',
                    ROOT / 'lib/features/translation_history/presentation/pages/translation_history_page.dart']
    if args.history_content:
        sources += [ROOT / 'lib/features/translation_history/presentation/pages/translation_history_page.dart',
                    ROOT / 'lib/features/translation_history/presentation/widgets/translation_history_load_state.dart']
        if args.kind == 'flutter':
            sources += [ROOT / 'tool/native_ui_reference/history_font_diagnostics.dart']
    evidence = {'shell_login_reference': args.shell_login, 'extracted_history_presentation': extracted_history, 'history_content_reference': args.history_content, 'history_empty_reference': args.history_empty, 'history_initial_reference': args.history_initial, 'record_time_reference': args.record_time, 'recording_scenario': args.recording_scenario if args.shell else None, 'reference_scene': 'language' if args.language else None, 'reference_state': args.outbound_state if args.outbound else None, 'native_head': HEAD, 'native_worktree_head': native_worktree_head,
                'native_fixed_sources': fixed_hashes if args.kind == 'native' else {},
                'simulator': args.simulator,
                'bundle_id': bundle_id,
                'flutter_head': read(['git', '-C', ROOT, 'rev-parse', 'HEAD']),
                'flutter_diff_sha256': hashlib.sha256(read([
                    'git', '-C', ROOT, 'diff', 'HEAD', '--', 'lib', 'tool', 'ios/Runner'
                ]).encode()).hexdigest(),
                'tool_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'sources': {
                    str(path.relative_to(NATIVE) if path.is_relative_to(NATIVE)
                        else path.relative_to(ROOT)):
                    hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}}
    (OUTPUT / (artifact + '-sources.json')).write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    print('Isolated simulator host compiled and launched; no business SDK registered.')


if __name__ == '__main__':
    main()
