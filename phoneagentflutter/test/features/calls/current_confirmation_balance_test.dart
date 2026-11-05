import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/confirmation_billing_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/controller/conversation_call_controller.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/calls/presentation/pages/confirmation_billing_route.dart';
import 'package:phone_agent/features/calls/presentation/pages/batch_confirmation_billing_route.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../support/call_admission_fixture.dart';

class _Wallet implements PointsWalletRepository {
  @override
  Future<PointsAccount> account() async => accountWith(1000);
  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      PointsLedgerPage(
        items: [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
      );
}

PointsAccount accountWith(int balance) => PointsAccount(
  totalBalance: balance,
  availableBalance: balance,
  heldBalance: 0,
  updatedAt: '',
);

void main() {
  testWidgets(
    'committed receipt clears launch before terminal rejection keeps command owner',
    (tester) async {
      final fixture = AdmissionFixture()..refreshed = 1000;
      late final ConversationCallController calls;
      calls = ConversationCallController(
        admission: fixture.service,
        sessions: PreviewCallFlow(CallFlowScenario.single),
        submit: (_) async {
          calls.bindConfirmationCommand('confirm-old');
        },
        onBlocked: (_) {},
        syncOutcome: (_, __) async => true,
      );
      addTearDown(calls.dispose);
      void present(String tool) => calls.receive(
        sessionId: 'session',
        commandId: 'proposal-$tool',
        toolId: tool,
        spec: {'targetName': '联系人', 'phoneNumber': '100', 'primaryGoal': '任务'},
      );
      present('old');
      final request = calls.snapshot.launch.request!;
      calls.reportPresented(request.identity, request.specSignature);
      expect(calls.confirm('确认拨打'), isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(calls.activeRequest, isNotNull);
      // This is the receipt path used when committed facts publish before SSE.
      calls.acceptReceipts([
        ConversationMessage(
          id: 'committed-result',
          role: MessageRole.assistant,
          text: '',
          transient: true,
          commandId: 'confirm-old',
          receipt: CallReceipt(
            attemptId: '',
            status: 'FAILED',
            metadata: const {'resultCode': 'POINTS_INSUFFICIENT_BALANCE'},
          ),
        ),
      ]);
      expect(calls.snapshot.launch.request, isNull);
      expect(calls.activeRequest, isNull);
      fixture.refreshed = 0;
      present('new');
      await calls.acceptPointsRejection(
        const AgentEvent(
          AgentEventKind.finalResponse,
          payload: {
            'type': 'CALL_RESULT',
            'callResult': {
              'metadata': {'resultCode': 'POINTS_INSUFFICIENT_BALANCE'},
            },
          },
        ),
        commandId: 'confirm-old',
      );
      expect(fixture.refreshes, greaterThan(0));
      expect(calls.snapshot.launch.request!.toolId, 'new');
    },
  );

  test(
    'SDK rejection refreshes wallet once per command after newer input',
    () async {
      final fixture = AdmissionFixture()..model = 'Doubao';
      final pending = Completer<int?>();
      fixture.onRefresh = () => pending.future;
      final calls = ConversationCallController(
        admission: fixture.service,
        sessions: PreviewCallFlow(CallFlowScenario.single),
        submit: (_) async {},
        onBlocked: (_) {},
        syncOutcome: (_, __) async => true,
      );
      addTearDown(calls.dispose);
      var published = 0;
      const event = AgentEvent(
        AgentEventKind.finalResponse,
        payload: {
          'type': 'BATCH_CALL_RESULT',
          'batchCallResult': {'resultCode': 'POINTS_INSUFFICIENT_BALANCE'},
        },
      );
      final settling = calls.acceptPointsRejection(
        event,
        commandId: 'confirm-old',
        onSettled: () => published++,
      );
      fixture.model = 'Qwen';
      calls.cancelPending();
      pending.complete(0);
      await settling;
      await calls.acceptPointsRejection(event, commandId: 'confirm-old');
      expect(fixture.refreshes, 1);
      expect(published, 1);
      await calls.acceptPointsRejection(event, commandId: 'confirm-new');
      expect(fixture.refreshes, 2);
    },
  );

  test(
    'latest pending batch is current without a single-call launch request',
    () {
      const batch = ConversationMessage(
        id: 'batch',
        role: MessageRole.assistant,
        text: '',
        batchConfirmation: BatchConfirmation(
          snapshotId: 'batch-tool',
          version: 1,
          title: '',
          sections: [],
          recipients: [],
          issues: [],
          rules: [],
          assistantText: '',
        ),
      );
      final single = ConversationMessage(
        id: 'single',
        role: MessageRole.assistant,
        text: '',
        confirmation: CallConfirmation(
          targetName: '合成联系人',
          phoneNumber: '100',
          primaryGoal: '任务',
          summaryLines: [],
        ),
      );
      expect(ConfirmationBillingRequest.currentBatch(batch, [batch]), isTrue);
      expect(
        ConfirmationBillingRequest.currentBatch(batch, [batch, single]),
        isFalse,
      );
    },
  );

  testWidgets(
    'batch card preserves sufficient snapshot after wallet depletion',
    (tester) async {
      final wallet = PointsWalletController(_Wallet())
        ..acceptServerAccount(accountWith(1000));
      final batch = BatchConfirmation(
        snapshotId: 'batch',
        version: 1,
        title: '',
        sections: [],
        recipients: [
          for (final id in ['one', 'two'])
            BatchConfirmationRecipient(
              id: id,
              name: '合成联系人',
              phone: '100',
              salutation: '',
              status: '',
              detail: '',
            ),
        ],
        issues: [],
        rules: [],
        assistantText: '',
      );
      final request = ConfirmationBillingRequest('session', [
        batch.billingAlias,
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pointsWalletControllerProvider.overrideWith((_) => wallet),
            confirmationBillingProvider(request).overrideWith(
              (_) async => const ConfirmationBillingSnapshot(
                modelTitle: 'Qwen',
                availableBalance: 1000,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BatchConfirmationBillingRoute(
                  sessionId: 'session',
                  confirmation: batch,
                  executable: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('100积分'), findsOneWidget);
      expect(find.text('多路积分不足'), findsNothing);
      wallet.acceptServerAccount(accountWith(0));
      await tester.pump();
      expect(find.text('100积分'), findsOneWidget);
      expect(find.text('多路积分不足'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final current in [true, false]) {
    testWidgets(
      'current and historic cards retain original balance: $current',
      (tester) async {
        final wallet = PointsWalletController(_Wallet())
          ..acceptServerAccount(accountWith(1000));
        final request = ConfirmationBillingRequest('session', ['tool']);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pointsWalletControllerProvider.overrideWith((_) => wallet),
              confirmationBillingProvider(request).overrideWith(
                (_) async => const ConfirmationBillingSnapshot(
                  modelTitle: 'Qwen',
                  availableBalance: 1000,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ConfirmationBillingRoute(
                  request: request,
                  executable: current,
                  confirmation: CallConfirmation(
                    targetName: '合成联系人',
                    phoneNumber: '100',
                    primaryGoal: '合成任务',
                    summaryLines: [],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('当前积分不足以发起'), findsNothing);
        wallet.acceptServerAccount(accountWith(0));
        await tester.pump();
        expect(find.textContaining('当前积分不足以发起'), findsNothing);
        wallet.acceptServerAccount(accountWith(1000));
        await tester.pump();
        expect(find.textContaining('当前积分不足以发起'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
