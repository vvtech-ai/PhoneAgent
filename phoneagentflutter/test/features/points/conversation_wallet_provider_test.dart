import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> _billing(String id) => {
  'billingSessionId': id,
  'billingState': 'SETTLED',
  'remainingPoints': 1,
  'chargedPoints': 100,
};

class _Wallet implements PointsWalletRepository {
  int reads = 0, ledgers = 0, balance = 900;
  @override
  Future<PointsAccount> account() async {
    reads++;
    return PointsAccount(
      totalBalance: balance,
      availableBalance: balance,
      heldBalance: 0,
      updatedAt: 'synthetic',
    );
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async {
    ledgers++;
    return PointsLedgerPage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
    );
  }
}

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>.broadcast();
  @override
  AgentRun start(AgentCommand command) => AgentRun(events.stream, () {});
}

class _History implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成历史',
          status: 'CLOSED',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          1,
          const LedgerProjection(
            status: 'CLOSED',
            continuable: false,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 1,
          ),
          [
            LedgerEvent(
              eventId: 'past',
              sessionId: sessionId,
              sequence: 1,
              type: 'CALL_COMPLETED',
              schemaVersion: 1,
              callAttemptId: 'past-call',
              payload: {
                'callReceipt': {
                  'status': 'COMPLETED',
                  'billingSummary': _billing('past-billing'),
                },
              },
            ),
          ],
        ),
      );
}

void main() {
  for (final restore in [false, true]) {
    test('formal conversation wallet wiring restore=$restore', () async {
      final server = SyntheticAccountApi();
      final wallet = _Wallet();
      final gateway = _Gateway();
      final entry = ConversationEntry(sessionId: 'synthetic', restore: restore);
      final container = ProviderContainer(
        overrides: [
          accountApiProvider.overrideWithValue(server.api),
          currentAccountIdProvider.overrideWithValue('synthetic'),
          pointsWalletRepositoryProvider.overrideWithValue(wallet),
          agentGatewayProvider.overrideWithValue(gateway),
          historyRepositoryProvider.overrideWithValue(_History()),
          taskErrorStatusSyncProvider.overrideWith((ref) {
            final sync = PreviewTaskErrorStatusPorts().createSync();
            ref.onDispose(sync.close);
            return sync;
          }),
          callAdmissionProvider(
            entry.sessionId,
          ).overrideWithValue(AdmissionFixture().service),
          callSessionRepositoryProvider.overrideWithValue(
            PreviewCallFlow(CallFlowScenario.single),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.events.close();
        server.api.close();
      });
      // Keep the already loaded home wallet alive before entering conversation.
      final walletKeep = container.listen(
        pointsWalletControllerProvider,
        (_, __) {},
      );
      addTearDown(walletKeep.close);
      await Future<void>.delayed(Duration.zero);
      expect(wallet.reads, 1);
      final keep = container.listen(
        conversationControllerProvider(entry),
        (_, __) {},
      );
      addTearDown(keep.close);
      final controller = container.read(
        conversationControllerProvider(entry).notifier,
      );
      await Future<void>.delayed(Duration.zero);
      if (!restore) {
        expect(wallet.reads, 1);
        expect(controller.send('合成文本'), isTrue);
        gateway.events.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'callResult': {
                'status': 'COMPLETED',
                'billingSummary': _billing('live'),
              },
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
      expect(wallet.reads, 2);
      expect(wallet.ledgers, 2);
      expect(
        container
            .read(pointsWalletControllerProvider)
            .account!
            .availableBalance,
        900,
      );
      expect(
        controller.state.messages.any((m) => m.receipt?.billing != null),
        isTrue,
      );
      controller.showNotice('不相关状态变化');
      await Future<void>.delayed(Duration.zero);
      expect(wallet.reads, 2);
      if (!restore) {
        wallet.balance = 800;
        gateway.events.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'callResult': {
                'status': 'COMPLETED',
                'billingSummary': _billing('live'),
              },
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(wallet.reads, 2);
        gateway.events.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'batchCallResult': {
                'batchId': 'batch',
                'items': [
                  {
                    'itemId': 'one',
                    'status': 'COMPLETED',
                    'billingSummaries': [_billing('batch-billing')],
                  },
                ],
              },
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(wallet.reads, 3);
        expect(wallet.ledgers, 3);
        expect(
          container
              .read(pointsWalletControllerProvider)
              .account!
              .availableBalance,
          800,
        );
      }
      expect(server.requests, isEmpty);
    });
  }
}
