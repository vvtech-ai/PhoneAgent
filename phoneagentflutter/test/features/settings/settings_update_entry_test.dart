import '../../support/pump_ui_transitions.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/about_providers.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/presentation/pages/app_update_page.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/startup_update_fakes.dart';
import '../../support/shell_fakes.dart';
import '../../support/conversation_fakes.dart';
import '../../support/initialized_identity.dart';

void main() {
  testWidgets('Android formal setting checks once directly and reports latest', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStorage.setMockInitialValues({});
    final models = _DelayedModels();
    final repo = StartupRepositoryFake()
      ..pending = Completer<AppUpdateRelease>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...initializedIdentityOverrides(),
          networkAvailabilitySourceProvider.overrideWithValue(
            const UnknownNetworkAvailability(),
          ),
          sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          callModelRepositoryProvider.overrideWithValue(models),
          taskRepositoryProvider.overrideWithValue(OfflineTasks()),
          historyRepositoryProvider.overrideWithValue(OfflineHistory()),
          agentGatewayProvider.overrideWithValue(OfflineAgent()),
          taskErrorStatusSyncProvider.overrideWith((ref) {
            final sync = PreviewTaskErrorStatusPorts().createSync();
            ref.onDispose(sync.close);
            return sync;
          }),
          // Isolate the manual setting from startup checks; installer is never used.
          startupUpdateSupportedProvider.overrideWithValue(false),
          aboutMetadataSourceProvider.overrideWithValue(StartupSourceFake()),
          installedAppSourceProvider.overrideWithValue(StartupSourceFake()),
          appUpdateRepositoryProvider.overrideWithValue(repo),
        ],
        child: const PhoneAgentApp(),
      ),
    );
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const Key('tab-3')));
    await tester.pumpUntilUiSettled();
    expect(repo.checks, 0);
    expect(find.byKey(const Key('settings-update')), findsNothing);
    expect(find.text('v1.0 ›'), findsNothing);
    expect(find.text('设置 ›'), findsOneWidget);
    expect(find.text('QwenOmni… ×1.0 ›'), findsOneWidget);
    final modelCard = find.byKey(const Key('settings-models'));
    final controller = ProviderScope.containerOf(
      tester.element(modelCard),
    ).read(callModelControllerProvider.notifier);
    models.pending = Completer<CallModelCatalog>();
    final loading = controller.load();
    await tester.pump();
    expect(find.text('加载中 ›'), findsOneWidget);
    expect(
      find.descendant(of: modelCard, matching: find.textContaining('×')),
      findsNothing,
    );
    models.pending!.completeError(StateError('synthetic'));
    await loading;
    await tester.pumpUntilUiSettled();
    expect(find.text('加载失败 ›'), findsOneWidget);
    expect(
      find.descendant(of: modelCard, matching: find.textContaining('×')),
      findsNothing,
    );
    models.pending = null;
    await controller.load();
    await tester.pumpUntilUiSettled();
    expect(find.text('QwenOmni… ×1.0 ›'), findsOneWidget);
    expect(repo.checks, 0);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-about')),
      180,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings-about'))),
      alignment: .3,
    );
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpUntilUiSettled();
    expect(repo.checks, 0);
    expect(find.text('V1.0'), findsOneWidget);
    final entry = find.byKey(const Key('about-update'));
    await tester.ensureVisible(entry);
    await tester.pumpUntilUiSettled();
    await tester.tap(entry);
    await tester.pump();
    expect(repo.checks, 1);
    expect(find.byType(AppUpdateRoute), findsNothing);
    expect(find.text('检测中'), findsOneWidget);
    expect(find.textContaining('检测中 ›'), findsNothing);
    await tester.tap(entry);
    await tester.pump();
    expect(repo.checks, 1);
    repo.pending!.complete(startupRelease(update: false));
    await tester.pumpUntilUiSettled();
    expect(find.text('当前已是最新版本'), findsOneWidget);
    expect(find.byType(AppUpdateRoute), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}

class _DelayedModels extends FakeCallModelRepository {
  Completer<CallModelCatalog>? pending;
  @override
  Future<CallModelCatalog> load() => pending?.future ?? super.load();
}
