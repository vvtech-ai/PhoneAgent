import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/restaurant_memory_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/conversation_fakes.dart';
import '../../support/shell_fakes.dart';
import '../../support/granted_task_entry.dart';
import '../../../tool/previews/shell_task_parity_ports.dart';
import 'conversation_questions_flow_test.dart' show Gateway;
import 'restaurant_contact_memory_offer_test.dart' show AskedStore;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform task route marks optional memory question and sends natural answer',
      (tester) async {
        final gateway = Gateway(), store = AskedStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...shellTaskParityOverrides(),
              conversationPermissionSourceProvider.overrideWithValue(
                const GrantedTaskEntry(),
              ),
              sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
              homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
              callModelRepositoryProvider.overrideWithValue(
                FakeCallModelRepository(),
              ),
              taskRepositoryProvider.overrideWithValue(OfflineTasks()),
              historyRepositoryProvider.overrideWithValue(OfflineHistory()),
              agentGatewayProvider.overrideWithValue(gateway),
              restaurantMemoryAskedStoreProvider.overrideWithValue(store),
              networkAvailabilitySourceProvider.overrideWithValue(
                const UnknownNetworkAvailability(),
              ),
              taskErrorStatusSyncProvider.overrideWith((ref) {
                final sync = PreviewTaskErrorStatusPorts().createSync();
                ref.onDispose(sync.close);
                return sync;
              }),
            ],
            child: const PhoneAgentApp(),
          ),
        );
        await tester.pumpUntilUiSettled();
        Future<void> tap(String key, {bool settle = true}) async {
          final target = find.byKey(ValueKey(key));
          await tester.ensureVisible(target);
          await tester.pumpUntilUiSettled();
          await tester.tap(target);
          if (settle) {
            await tester.pumpUntilUiSettled();
          } else {
            await tester.pump();
          }
        }

        await tap('tab-2');
        await tap('conversation:closed');
        expect(store.writes, 0);
        await tap('toggle-text');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '本次预订人用合成联系人',
        );
        await tap('send-text', settle: false);
        gateway.stream.add(
          const AgentEvent(
            AgentEventKind.signal,
            payload: {
              'type': 'ASK_USER',
              'pendingToolCallId': 'memory-offer',
              'questions': {
                'items': [
                  {
                    'id': 'restaurantContactMemoryConsent',
                    'prompt': '要不要记住这位预订人的姓名和手机号？下次订餐可以直接使用。',
                    'answerType': 'confirm',
                    'required': false,
                  },
                ],
              },
            },
          ),
        );
        gateway.stream.add(const AgentEvent(AgentEventKind.done));
        await tester.pumpUntilUiSettled();
        expect(store.writes, 1);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '不用记住，继续订餐',
        );
        await tap('send-text', settle: false);
        expect(gateway.commands.last.pendingToolCallId, 'memory-offer');
        expect(gateway.commands.last.message, '不用记住，继续订餐');
        expect(gateway.commands.last.actionId, isNull);
        expect(store.writes, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
