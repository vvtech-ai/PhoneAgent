import '../../support/pump_ui_transitions.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_creation_port.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/system_voice_preview_host.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/conversation_fakes.dart';
import '../../support/shell_fakes.dart';
import '../../support/initialized_identity.dart';
import '../../support/granted_task_entry.dart';
import 'package:phone_agent/app/agent_context_providers.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('formal app model settings and task navigation at $width', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final models = FakeCallModelRepository(doubaoSupportsVoiceClone: false);
      final agent = OfflineAgent();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...initializedIdentityOverrides(),
            conversationPermissionSourceProvider.overrideWithValue(
              const GrantedTaskEntry(),
            ),
            logReportRepositoryProvider.overrideWithValue(_FailingLogs()),
            cloneCreationPortProvider.overrideWithValue(
              PreviewCloneCreationPort(CloneCreationScenario.absent),
            ),
            networkAvailabilitySourceProvider.overrideWithValue(
              const UnknownNetworkAvailability(),
            ),
            sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
            homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
            callModelRepositoryProvider.overrideWithValue(models),
            taskRepositoryProvider.overrideWithValue(OfflineTasks()),
            taskErrorStatusSyncProvider.overrideWith((ref) {
              final sync = PreviewTaskErrorStatusPorts().createSync();
              ref.onDispose(sync.close);
              return sync;
            }),
            historyRepositoryProvider.overrideWithValue(OfflineHistory()),
            agentGatewayProvider.overrideWithValue(agent),
          ],
          child: const PhoneAgentApp(),
        ),
      );
      await tester.pumpUntilUiSettled();
      Future<void> tapKey(String key) async {
        final target = find.byKey(ValueKey(key));
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(target, 200);
          await tester.pumpUntilUiSettled();
        }
        await Scrollable.ensureVisible(tester.element(target), alignment: .3);
        await tester.pumpUntilUiSettled();
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      await tapKey('homeVoiceModelChip');
      expect(find.text('选择 AI 通话模型'), findsOneWidget);
      expect(find.byKey(const ValueKey('voices-DOUBAO')), findsNothing);
      await tapKey('model-DOUBAO');
      expect(find.byType(CallModelsPage), findsNothing);
      expect(models.provider, 'DOUBAO');
      await tapKey('homeVoiceModelChip');
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      expect(find.byType(CallModelsPage), findsNothing);
      await tapKey('tab-3');
      expect(find.byKey(const Key('settings-logs')), findsNothing);
      await tapKey('settings-about');
      expect(find.byKey(const Key('about-logs')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-models')),
        -180,
      );
      expect(find.byKey(const Key('settings-models')), findsOneWidget);
      await tapKey('settings-models');
      expect(find.byType(CallModelsPage), findsOneWidget);
      expect(find.text('Andre'), findsOneWidget);
      expect(find.text('清朗男声'), findsOneWidget);
      await tapKey('voices-DOUBAO');
      expect(find.byType(CallVoicesPage), findsOneWidget);
      expect(
        tester
            .widget<SystemVoicePreviewHost>(find.byType(SystemVoicePreviewHost))
            .modelId,
        'DOUBAO',
      );
      await tapKey('backFromVoiceIdentity');
      await tapKey('voices-QWEN_OMNI_PLUS');
      expect(find.byType(CallVoicesPage), findsOneWidget);
      expect(find.text('创建克隆交互演练（MOCK）'), findsNothing);
      expect(find.text('声音克隆'), findsOneWidget);
      expect(
        find.byType(CallModelsPage),
        findsOneWidget,
      ); // Directory under sheet.
      await tapKey('voice-v2');
      expect(models.voice, 'v2');
      await tapKey('backFromVoiceIdentity');
      expect(find.byType(CallModelsPage), findsOneWidget);
      expect(find.text('音色二'), findsOneWidget);
      expect(
        find.bySemanticsLabel('QwenOmniPlus 的通话声音，音色二，支持系统音色和声音克隆'),
        findsOneWidget,
      );
      await tapKey('backFromVoiceModel');
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-models')),
        -180,
      );
      expect(find.byKey(const Key('settings-models')), findsOneWidget);
      await tapKey('tab-2');
      final pages = container.read(pageRouteVisibilityProvider);
      expect(
        pages.navigator,
        same(
          container
              .read(appRouterProvider)
              .routerDelegate
              .navigatorKey
              .currentState,
        ),
      );
      final taskPage = pages.currentPage;
      await tapKey('conversation:closed');
      expect(pages.currentPage, isNot(same(taskPage)));
      expect(find.text('历史任务已保存，可继续对话。'), findsOneWidget);
      expect(agent.commands, isEmpty);
      expect(find.text('历史任务已保存，可继续对话。'), findsOneWidget);
      expect(agent.commands, isEmpty);
      await tapKey('close-conversation');
      expect(pages.currentPage, same(taskPage));
      await tapKey('tab-0');
      expect(find.byType(CallModelsPage), findsNothing);
      expect(find.byType(CallVoicesPage), findsNothing);
      expect(models.voice, 'v2');
      final released = container
          .read(sessionControllerProvider.notifier)
          .signOut();
      await tester.pumpUntilUiSettled();
      await released;
      await tester.pumpUntilUiSettled();
      final nextPages = container.read(pageRouteVisibilityProvider);
      expect(nextPages, isNot(same(pages)));
      expect(
        nextPages.navigator,
        same(
          container
              .read(appRouterProvider)
              .routerDelegate
              .navigatorKey
              .currentState,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailingLogs implements AppLogRepository {
  @override
  Future<AppLogBundle> prepare() async =>
      throw StateError('synthetic log failure');
  @override
  Future<void> upload(AppLogBundle bundle) =>
      throw StateError('unexpected upload');
  @override
  Future<void> acknowledge(AppLogBundle bundle) =>
      throw StateError('unexpected acknowledgement');
}
