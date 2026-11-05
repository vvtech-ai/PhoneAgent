import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/translation_history_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/conversation_fakes.dart';
import '../../support/shell_fakes.dart';
import '../../support/initialized_identity.dart';
import '../../support/granted_task_entry.dart';
import '../../support/translation_history_fake.dart';
import '../../../tool/previews/shell_task_parity_ports.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('shared app restore/text/options/back/history at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = OfflineAgent();
      final translations = OfflineTranslationHistory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...shellTaskParityOverrides(),
            ...initializedIdentityOverrides(),
            conversationPermissionSourceProvider.overrideWithValue(
              const GrantedTaskEntry(),
            ),
            networkAvailabilitySourceProvider.overrideWithValue(
              const UnknownNetworkAvailability(),
            ),
            sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
            homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
            callModelRepositoryProvider.overrideWithValue(
              FakeCallModelRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(OfflineTasks()),
            taskErrorStatusSyncProvider.overrideWith((ref) {
              final sync = PreviewTaskErrorStatusPorts().createSync();
              ref.onDispose(sync.close);
              return sync;
            }),
            historyRepositoryProvider.overrideWithValue(OfflineHistory()),
            agentGatewayProvider.overrideWithValue(gateway),
            translationHistoryRepositoryProvider.overrideWithValue(
              translations,
            ),
          ],
          child: const PhoneAgentApp(),
        ),
      );
      await tester.pumpUntilUiSettled();
      Future<void> tap(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
        await tester.tap(finder);
        await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }

      await tap('tab-2');
      await tap('conversation:closed');
      expect(find.text('历史任务已保存，可继续对话。'), findsOneWidget);
      expect(gateway.commands, isEmpty, reason: 'restoring must not submit');
      await tap('toggle-text');
      final input = find.byKey(const ValueKey('conversation-input'));
      await tester.enterText(input, '再推荐两家餐厅');
      await tester.pump();
      await tap('send-text');
      expect(find.text('请选择餐厅'), findsOneWidget);
      final option = find.text('合成餐厅乙');
      await tester.ensureVisible(option);
      await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
      await tester.tap(option);
      await tester.pumpUntilUiSettled(const Duration(milliseconds: 200));
      expect(gateway.commands.length, 2);
      expect(gateway.commands.last.message, '第 2 个');
      expect(gateway.commands.last.pendingToolCallId, 'choice');
      expect(
        gateway.commands.every((c) => c.toJson()['channel'] == 'voice'),
        isTrue,
      );
      expect(find.text('已收到你的选择。'), findsOneWidget);
      await tap('close-conversation');
      await tap('conversation:closed');
      expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
      expect(gateway.commands.length, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      expect(find.byKey(const ValueKey('toggle-text')), findsNothing);
      translations.fail = true;
      await tap('call:translation');
      expect(find.byKey(const ValueKey('retry-translation')), findsOneWidget);
      translations.fail = false;
      await tap('retry-translation');
      expect(find.text('Hello?'), findsOneWidget);
      await tap('close-translation');
      await tap('call:ordinary');
      await tap('task-detail-restore');
      expect(find.text('历史任务已保存，可继续对话。'), findsNothing);
      await tap('close-conversation');
      expect(gateway.commands.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}
