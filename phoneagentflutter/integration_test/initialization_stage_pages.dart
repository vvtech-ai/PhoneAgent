import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/initialization_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';
import 'package:phone_agent/features/translation/data/preview_translation_configuration.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_catalog_fakes.dart';
import '../tool/previews/workbench_catalog.dart';

/// v66 formal AuthRoute bypasses the retained historical initialization host.
Future<void> verifyInitializationStage(
  WidgetTester tester, {
  required bool skip,
  required Future<void> Function(String) capture,
}) async {
  final scene = workbenchScenes.singleWhere(
    (s) => s.id == 'initialization-app',
  );
  await tester.pumpWidget(
    MigrationWorkbench(key: ValueKey(skip), scenes: [scene]),
  );
  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  await tester.pumpUntilUiSettled();
  await tap(find.byKey(const ValueKey('scene-initialization-app')));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  expect(container.read(appConfigProvider).apiBaseUri, isNull);
  final auth = container.read(sessionStoreProvider) as AuthScenario;
  final models =
      container.read(callModelRepositoryProvider) as FakeCallModelRepository;
  final identity =
      container.read(identityRepositoryProvider) as PreviewIdentityCleanup;
  final translation =
      container.read(translationPreferenceStoreProvider)
          as PreviewTranslationPreferenceStore;
  final originalTranslation = translation.value;
  expect(find.text('身份信息'), findsNothing);
  expect(find.byKey(const ValueKey('init-name')), findsNothing);
  expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
  expect(container.exists(initializationControllerProvider), isFalse);
  expect(container.exists(translationSetupProvider), isFalse);
  await capture(
    skip ? '50-no-initialization-home' : '47-no-initialization-home',
  );
  await tap(find.byKey(const ValueKey('tab-2')));
  await capture(
    skip ? '51-no-initialization-tasks' : '48-no-initialization-tasks',
  );
  await tap(find.byKey(const ValueKey('tab-0')));
  expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
  expect(find.text('同声传译模型'), findsNothing);
  expect(models.provider, 'QWEN_OMNI_PLUS');
  expect(models.saves, 0);
  expect(identity.value.name, '');
  expect(identity.skipWrites, 0);
  expect(translation.value, same(originalTranslation));
  expect(container.exists(translationSetupProvider), isFalse);
  expect(auth.sends, 0);
  expect(auth.submissions, isEmpty);
  expect(container.exists(initializationControllerProvider), isFalse);
  await tester.pumpUntilUiSettled();
  expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
  expect(models.saves, 0);
  await capture(
    skip ? '52-no-initialization-return' : '49-no-initialization-return',
  );
  await tap(find.byKey(const ValueKey('workbench-home')));
}
