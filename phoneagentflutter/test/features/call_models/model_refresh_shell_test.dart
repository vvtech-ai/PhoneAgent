import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/conversation_fakes.dart';
import '../../support/initialized_identity.dart';
import '../../support/pump_ui_transitions.dart';
import '../../support/shell_fakes.dart';

class CountingModels extends FakeCallModelRepository {
  int reads = 0;
  @override
  Future<CallModelCatalog> load() {
    reads++;
    return super.load();
  }
}

void main() {
  testWidgets(
    'home task settings sheet return and resume all refresh directory',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final models = CountingModels();
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
            taskErrorStatusSyncProvider.overrideWith((ref) {
              final sync = PreviewTaskErrorStatusPorts().createSync();
              ref.onDispose(sync.close);
              return sync;
            }),
            historyRepositoryProvider.overrideWithValue(OfflineHistory()),
            agentGatewayProvider.overrideWithValue(OfflineAgent()),
          ],
          child: const PhoneAgentApp(),
        ),
      );
      await tester.pumpUntilUiSettled();
      expect(models.reads, greaterThan(0));
      Future<void> refreshed(String key) async {
        final before = models.reads;
        final target = find.byKey(ValueKey(key));
        await Scrollable.ensureVisible(tester.element(target));
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(models.reads, greaterThan(before), reason: key);
        expect(tester.takeException(), isNull);
      }

      await refreshed('tab-2');
      await refreshed('tab-3');
      await refreshed('settings-models');
      await tester.tap(find.byKey(const ValueKey('model-DOUBAO')));
      await tester.pump();
      await tester.pump();
      expect(models.provider, 'DOUBAO');
      expect(find.text('通话模型已切换为 Seeduplex'), findsOneWidget);
      dismissNativeNotice();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('model-DOUBAO')));
      await tester.pump();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      models.fail = true;
      await tester.tap(find.byKey(const ValueKey('model-QWEN_OMNI_PLUS')));
      await tester.pump();
      await tester.pump();
      expect(models.provider, 'DOUBAO');
      expect(find.text('通话模型切换失败，请检查网络或本地服务连接'), findsOneWidget);
      dismissNativeNotice();
      models.fail = false;
      await tester.pump();
      await refreshed('backFromVoiceModel');
      await refreshed('tab-0');
      await refreshed('homeVoiceModelChip');
      final beforeResume = models.reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpUntilUiSettled();
      expect(models.reads, greaterThan(beforeResume));
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    },
  );
}
