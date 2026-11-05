import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'agent_document_stage_pages.dart';
import 'dial_translation_stage_pages.dart';
import 'call_log_stage_pages.dart';
import 'developer_stage_pages.dart';
import 'initialization_stage_pages.dart';

List<String> guardMigrationIncrement() {
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'dev.flutter.pigeon.file_selector_android.FileSelectorApi.openFile',
    'dev.flutter.pigeon.file_selector_android.FileSelectorApi.openFiles',
    'dev.flutter.pigeon.file_selector_ios.FileSelectorApi.openFile',
  ]) {
    messenger.setMockMessageHandler(name, (_) async {
      calls.add(name);
      return const StandardMessageCodec().encodeMessage([null]);
    });
    addTearDown(() => messenger.setMockMessageHandler(name, null));
  }
  for (final name in [
    'plugins.it_nomads.com/flutter_secure_storage',
    'com.vvtech.phone_agent/system_dialer',
    'plugins.flutter.io/file_selector',
    'phone_agent/pcm_output',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('$name:${call.method}');
      throw PlatformException(code: 'forbidden_in_stage');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  return calls;
}

Future<void> verifyMigrationIncrement(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
      ),
    );
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const ValueKey('scene-app')));
    await tester.pumpUntilUiSettled();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final auth = container.read(sessionStoreProvider) as AuthScenario;
    await verifyDialTranslationStage(tester, capture: capture);
    await verifyCallLogStage(tester, capture: capture);
    await verifyDeveloperStage(tester, capture: capture);
    expect(auth.sends, 0);
    expect(auth.submissions, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workbench-home')));
    await tester.pumpUntilUiSettled();
    for (final skip in [false, true]) {
      await verifyInitializationStage(tester, skip: skip, capture: capture);
    }
  }
  await verifyAgentDocumentStage(tester, capture: capture);
}
