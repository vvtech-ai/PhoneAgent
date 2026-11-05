import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/domain/receipts/native_call_receipt_presentation.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_outcome_scope.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/receipt_sections.dart';

void main() {
  CallReceipt committedReceipt(Map<String, Object?> result) =>
      CallReceiptProjector.project([
        LedgerEvent(
          eventId: 'committed-ui',
          sessionId: 'ui',
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'ui-command',
          payload: {'callResult': result},
        ),
      ]).single.receipt;

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform semantic booking reason stays hidden while short headline remains visible',
      (tester) async {
        const semanticReason = '商家未正式确认订位，短信答复亦未确认';
        const headline = '通话未获明确订位确认，短信发送未确认';
        const physicalDetail =
            'assistant: 请问能否订位\nmerchant: 目前无法确认\nassistant: 请短信答复';
        LedgerEvent fact(
          int sequence,
          String type,
          Map<String, Object?> payload,
          String command, {
          String? eventAttempt = 'same-attempt',
        }) => LedgerEvent(
          eventId: 'e$sequence',
          sessionId: 'synthetic-session',
          sequence: sequence,
          type: type,
          schemaVersion: 1,
          commandId: command,
          taskId: 'same-task',
          callAttemptId: eventAttempt,
          payload: payload,
        );
        final facts = [
          fact(20, 'CALL_REQUESTED', const {}, 'call-command-uuid'),
          fact(22, 'CALL_COMPLETED', const {}, 'call-command-uuid'),
          fact(23, 'CALL_OUTCOME_REPORTED', {
            'outcome': 'UNCLEAR',
            'headline': headline,
            'reason': semanticReason,
            'receiptFields': [
              {'key': 'taskType', 'label': '任务类型', 'value': '订餐'},
              {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
            ],
          }, 'agent-report-tool-call'),
          fact(
            25,
            'ASSISTANT_TURN_COMMITTED',
            {
              'callResult': {
                'status': 'UNCLEAR',
                'headline': headline,
                'detail': physicalDetail,
                'receiptFields': [
                  {'key': 'taskType', 'label': '任务', 'value': '订餐'},
                  {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
                ],
                'billingSummary': {
                  'billingSessionId': 'synthetic-billing',
                  'billingState': 'SETTLED',
                  'displayDurationSeconds': 108,
                  'chargedPoints': 180,
                },
                'metadata': {
                  'callAttemptId': 'same-attempt',
                  'agentOutcome': 'UNCLEAR',
                  'agentReason': semanticReason,
                },
              },
            },
            'user-command',
            eventAttempt: null,
          ),
        ];
        expect(facts.last.callAttemptId, isNull);
        final reported = CallReceiptProjector.project(facts.take(3)).single;
        final committed = CallReceiptProjector.project(facts).single;
        expect(reported.anchor.eventId, committed.anchor.eventId);
        expect(reported.receipt.attemptId, committed.receipt.attemptId);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: reported.receipt)),
          ),
        );
        expect(find.text('任务未完成'), findsOneWidget);
        expect(find.text('未完成'), findsOneWidget);
        expect(find.text(semanticReason), findsNothing);
        expect(
          tester.widget<ReceiptShell>(find.byType(ReceiptShell)).borderColor,
          const Color(0x33E14D46),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: committed.receipt)),
          ),
        );
        expect(find.text('任务未完成'), findsOneWidget);
        expect(find.text('未完成'), findsOneWidget);
        expect(committed.receipt.detail, physicalDetail);
        expect(committed.receipt.metadata['agentReason'], semanticReason);
        expect(
          NativeCallReceiptPresentation(committed.receipt).booking,
          isTrue,
        );
        expect(committed.receipt.billing?.durationSeconds, 108);
        expect(committed.receipt.billing?.chargedPoints, 180);
        expect(find.text(headline), findsOneWidget);
        expect(find.text(semanticReason), findsNothing);
        expect(find.text('108 秒'), findsOneWidget);
        expect(find.text('180'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText && widget.data == physicalDetail,
          ),
          findsNothing,
        );
        expect(find.text('结果未确认'), findsNothing);
        expect(
          tester.widget<ReceiptShell>(find.byType(ReceiptShell)).borderColor,
          const Color(0x33E14D46),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform reported booking uncertainty is a finished incomplete card',
      (tester) async {
        const reason = '通话未获明确订位确认，短信发送未确认';
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '订餐未完成',
          'detail': reason,
          'receiptFields': [
            {'key': 'taskType', 'label': '任务类型', 'value': '订餐'},
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
          'metadata': {
            'sceneType': 'restaurant_booking',
            'agentOutcome': 'UNCLEAR',
            'resultCode': 'INCOMPLETE_OR_UNCLEAR',
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('任务未完成'), findsOneWidget);
        expect(find.text('未完成'), findsOneWidget);
        expect(find.text(reason), findsOneWidget);
        expect(find.text('结果确认中'), findsNothing);
        expect(find.text('结果未确认'), findsNothing);
        final shell = tester.widget<ReceiptShell>(find.byType(ReceiptShell));
        expect(shell.borderColor, const Color(0x33E14D46));
        expect(receipt.metadata['agentOutcome'], 'UNCLEAR');
        expect(receipt.metadata['resultCode'], 'INCOMPLETE_OR_UNCLEAR');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform committed unclear status without agent outcome is terminal',
      (tester) async {
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'detail': '尚无明确结论',
          'receiptFields': [
            {'key': 'restaurantName', 'label': '商家', 'value': '合成目标'},
          ],
          'metadata': {'committedCallResult': 'true'},
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('结果确认中'), findsNothing);
        expect(find.text('任务未完成'), findsOneWidget);
        expect(
          tester.widget<ReceiptShell>(find.byType(ReceiptShell)).borderColor,
          const Color(0x33E14D46),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform live unclear final without agent outcome is terminal',
      (tester) async {
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '订餐未完成',
          'receiptFields': [
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('任务未完成'), findsOneWidget);
        expect(find.text('结果确认中'), findsNothing);
        expect(
          tester.widget<ReceiptShell>(find.byType(ReceiptShell)).borderColor,
          const Color(0x33E14D46),
        );
      },
    );

    testWidgets(
      '$platform incomplete booking retains multi-line reason outside the task card',
      (tester) async {
        const reason = '通话未获明确订位确认\n短信发送未确认';
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '订餐未完成',
          'detail': 'merchant: 通话已结束',
          'metadata': {
            'sceneType': 'restaurant_booking',
            'agentOutcome': 'UNCLEAR',
            'agentReason': reason,
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(receipt.metadata['agentReason'], reason);
        expect(find.text(reason), findsNothing);
        expect(find.text('结果确认中'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform incomplete task card keeps short business content and hides diagnostics',
      (tester) async {
        const internalReason =
            '挂断后未收到可信物理终态，任务结果仍需核实 (terminationCause=SYSTEM_STOP)';
        final longRequest = List.filled(
          8,
          '请预留安静区域，同行有老人，优先安排靠窗且方便进出的座位。',
        ).join();
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '通话中断，订位未确认',
          'detail': internalReason,
          'receiptFields': [
            {'key': 'taskType', 'label': '任务类型', 'value': 'FOOD_ORDERING'},
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
            {'key': 'arrivalTime', 'label': '时间', 'value': '今晚 19:00'},
            {'key': 'guestCount', 'label': '人数', 'value': '3 人'},
            {
              'key': 'policyCode',
              'label': '业务分类',
              'value': 'NO_RESERVATION_REQUIRED',
            },
            {'key': 'specialRequest', 'label': '备注', 'value': longRequest},
            {'key': 'failureReason', 'label': '原因', 'value': '商家未确认订位'},
            {'key': 'errorDiagnostic', 'label': '诊断', 'value': 'SYSTEM_STOP'},
          ],
          'billingSummary': {
            'billingSessionId': 'synthetic-billing',
            'billingState': 'SETTLED',
            'displayDurationSeconds': 60,
            'chargedPoints': 110,
            'remainingPoints': 105,
          },
          'metadata': {
            'sceneType': 'RESTAURANT_BOOKING',
            'agentOutcome': 'UNCLEAR',
            'agentReason': internalReason,
            'resultReason': internalReason,
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('任务未完成'), findsOneWidget);
        expect(find.text('未完成'), findsOneWidget);
        expect(find.text('餐厅'), findsOneWidget);
        expect(find.text('合成餐厅'), findsOneWidget);
        expect(find.text('FOOD_ORDERING'), findsOneWidget);
        expect(find.text('NO_RESERVATION_REQUIRED'), findsOneWidget);
        expect(find.text('时间'), findsOneWidget);
        expect(find.text('今晚 19:00'), findsOneWidget);
        expect(find.text('人数'), findsOneWidget);
        expect(find.text('3 人'), findsOneWidget);
        expect(find.text(longRequest), findsOneWidget);
        expect(find.text('通话中断，订位未确认'), findsOneWidget);
        expect(find.text('原因'), findsOneWidget);
        expect(find.text('商家未确认订位'), findsOneWidget);
        expect(find.text('60 秒'), findsOneWidget);
        expect(find.text('110'), findsOneWidget);
        expect(find.text('105'), findsOneWidget);
        expect(find.text('诊断'), findsNothing);
        expect(find.textContaining('terminationCause'), findsNothing);
        expect(find.textContaining('SYSTEM_STOP'), findsNothing);
        expect(receipt.metadata['agentReason'], internalReason);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform long diagnostic detail without metadata stays off task card',
      (tester) async {
        final diagnostic = List.filled(8, '挂断后未收到可信物理终态，需继续核对服务链路。').join();
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '通话中断，订位未确认',
          'detail': diagnostic,
          'receiptFields': [
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
          'metadata': {'agentOutcome': 'UNCLEAR'},
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('通话中断，订位未确认'), findsOneWidget);
        expect(find.text(diagnostic), findsNothing);
        expect(find.text('合成餐厅'), findsOneWidget);
      },
    );

    testWidgets(
      '$platform resultReason mirrored in detail stays off task card',
      (tester) async {
        const internalReason = '通话终态还未汇总，需等待内部链路核对';
        final receipt = CallReceipt.fromResult({
          'status': 'UNCLEAR',
          'headline': '通话中断，订位未确认',
          'detail': internalReason,
          'receiptFields': [
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
          'metadata': {
            'agentOutcome': 'UNCLEAR',
            'resultReason': internalReason,
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('通话中断，订位未确认'), findsOneWidget);
        expect(find.text(internalReason), findsNothing);
        expect(receipt.metadata['resultReason'], internalReason);
      },
    );

    testWidgets(
      '$platform execution error without task fields hides diagnostics',
      (tester) async {
        const diagnostic = '后台链路中断 (terminationCause=SYSTEM_STOP)';
        final receipt = CallReceipt.fromResult({
          'status': 'EXECUTION_ERROR',
          'headline': '服务暂不可用',
          'detail': diagnostic,
          'metadata': {'agentReason': diagnostic},
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text('执行结果'), findsOneWidget);
        expect(find.text('执行异常'), findsOneWidget);
        expect(find.text('原因'), findsOneWidget);
        expect(find.text('服务暂不可用'), findsOneWidget);
        expect(find.textContaining('terminationCause'), findsNothing);
        expect(receipt.metadata['agentReason'], diagnostic);
      },
    );

    testWidgets('$platform non-task call failure keeps its original reason', (
      tester,
    ) async {
      final receipt = CallReceipt.fromResult({
        'status': 'FAILED',
        'headline': '通话失败',
        'detail': '对方无人接听',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(body: CallReceiptCard(receipt: receipt)),
        ),
      );
      expect(find.text('通话失败'), findsOneWidget);
      expect(find.text('原因'), findsOneWidget);
      expect(find.text('对方无人接听'), findsOneWidget);
    });

    testWidgets('$platform successful task keeps its structured reason field', (
      tester,
    ) async {
      final receipt = CallReceipt.fromResult({
        'status': 'COMPLETED',
        'receiptFields': [
          {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          {'key': 'reason', 'label': '原因', 'value': '按要求完成'},
        ],
        'metadata': {'agentOutcome': 'SUCCESS'},
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(body: CallReceiptCard(receipt: receipt)),
        ),
      );
      expect(find.text('任务完成'), findsOneWidget);
      expect(find.text('餐厅'), findsOneWidget);
      expect(find.text('原因'), findsOneWidget);
      expect(find.text('按要求完成'), findsOneWidget);
    });

    testWidgets(
      '$platform physical close shows v66 pending tip until final result',
      (tester) async {
        final receipt = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'CALL_COMPLETED',
          'detail': '通话已结束，订餐结果待确认',
          'metadata': {
            'sceneType': 'FOOD_ORDERING',
            'resultCode': 'INCOMPLETE_OR_UNCLEAR',
          },
        });
        Widget page(
          CallReceipt current, {
          required bool awaiting,
          CallReceipt? previous,
        }) => MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: CallOutcomeScope(
              awaiting: awaiting,
              callAttemptId: current.attemptId,
              callId: current.callId,
              child: ConversationPage(
                state: ConversationState(
                  entry: const ConversationEntry(
                    sessionId: 'synthetic-session',
                  ),
                  messages: [
                    if (previous != null)
                      ConversationMessage(
                        id: 'previous-receipt',
                        role: MessageRole.assistant,
                        text: '',
                        receipt: previous,
                      ),
                    ConversationMessage(
                      id: 'synthetic-receipt',
                      role: MessageRole.assistant,
                      text: '',
                      receipt: current,
                    ),
                  ],
                ),
                modelName: '合成模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, _) => false,
                onRetry: () {},
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        );

        await tester.pumpWidget(page(receipt, awaiting: true));
        await tester.pump();
        expect(find.text('正在确认通话结果'), findsOneWidget);
        expect(find.byType(NativeThinkingCard), findsNothing);
        expect(find.byType(CallReceiptCard), findsNothing);
        expect(find.text('通话已结束，结果待核实'), findsNothing);

        await tester.pumpWidget(page(receipt, awaiting: false));
        await tester.pump();
        expect(find.text('· 正在整理通话结果'), findsNothing);
        expect(find.text('通话已结束，结果待核实'), findsOneWidget);
        expect(find.byType(CallReceiptCard), findsNothing);

        final physicalWithCopiedOutcome = CallReceipt(
          attemptId: 'synthetic-attempt',
          status: 'COMPLETED',
          metadata: {'physicalTerminalOnly': 'true', 'agentOutcome': 'UNCLEAR'},
        );
        await tester.pumpWidget(
          page(physicalWithCopiedOutcome, awaiting: true),
        );
        await tester.pump();
        expect(find.text('正在确认通话结果'), findsOneWidget);
        expect(find.byType(CallReceiptCard), findsNothing);

        List<LedgerEvent> physicalFacts(String callState) => [
          LedgerEvent(
            eventId: 'requested-$callState',
            sessionId: 'synthetic-session',
            sequence: 1,
            type: 'CALL_REQUESTED',
            schemaVersion: 1,
            commandId: 'synthetic-command',
            callAttemptId: 'synthetic-attempt',
            payload: const {},
          ),
          LedgerEvent(
            eventId: 'completed-$callState',
            sessionId: 'synthetic-session',
            sequence: 2,
            type: 'CALL_COMPLETED',
            schemaVersion: 1,
            commandId: 'synthetic-command',
            callAttemptId: 'synthetic-attempt',
            payload: {
              'resultCode': 'SDK_PHYSICAL_ENDED',
              'summary': '任务失败，等待业务结果',
              'callReceipt': {
                'callState': callState,
                'resultCode': 'SDK_PHYSICAL_ENDED',
                'resultReason': '任务失败，等待业务结果',
              },
            },
          ),
        ];
        for (final callState in ['COMPLETED', 'ENDED']) {
          final physical = CallReceiptProjector.project(
            physicalFacts(callState),
          ).single.receipt;
          expect(physical.status, callState);
          expect(physical.metadata['physicalTerminalOnly'], 'true');
          await tester.pumpWidget(page(physical, awaiting: true));
          await tester.pump();
          expect(find.text('正在确认通话结果'), findsOneWidget);
          expect(find.byType(CallReceiptCard), findsNothing);
          await tester.pumpWidget(page(physical, awaiting: false));
          await tester.pump();
          expect(find.text('通话已结束，结果待核实'), findsOneWidget);
          expect(find.byType(CallReceiptCard), findsNothing);
        }

        final committedCompleted = CallReceiptProjector.project([
          ...physicalFacts('COMPLETED'),
          LedgerEvent(
            eventId: 'committed-completed',
            sessionId: 'synthetic-session',
            sequence: 3,
            type: 'ASSISTANT_TURN_COMMITTED',
            schemaVersion: 1,
            commandId: 'synthetic-command',
            callAttemptId: 'synthetic-attempt',
            payload: {
              'callResult': {'status': 'COMPLETED', 'detail': '业务结果已返回'},
            },
          ),
        ]).single.receipt;
        expect(committedCompleted.metadata['physicalTerminalOnly'], isNull);
        await tester.pumpWidget(page(committedCompleted, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsNothing);
        expect(find.text('通话已结束，结果待核实'), findsOneWidget);

        for (final resultCode in [
          'SUCCESS_CONFIRMED',
          'NO_RESERVATION_REQUIRED',
          'NO_ANSWER',
        ]) {
          final withResultCode = CallReceiptProjector.project([
            physicalFacts('COMPLETED').first,
            LedgerEvent(
              eventId: 'completed-$resultCode',
              sessionId: 'synthetic-session',
              sequence: 2,
              type: 'CALL_COMPLETED',
              schemaVersion: 1,
              commandId: 'synthetic-command',
              callAttemptId: 'synthetic-attempt',
              payload: {
                'callReceipt': {
                  'callState': 'COMPLETED',
                  'resultCode': resultCode,
                },
              },
            ),
          ]).single.receipt;
          await tester.pumpWidget(page(withResultCode, awaiting: true));
          await tester.pump();
          expect(find.text('正在确认通话结果'), findsOneWidget);
          expect(find.byType(CallReceiptCard), findsNothing);
          await tester.pumpWidget(page(withResultCode, awaiting: false));
          await tester.pump();
          expect(find.text('通话已结束，结果待核实'), findsOneWidget);
          expect(find.byType(CallReceiptCard), findsNothing);
        }

        for (final outcome in ['PENDING', 'UNKNOWN']) {
          final unreported = CallReceipt.fromResult({
            'callAttemptId': 'synthetic-attempt',
            'status': 'COMPLETED',
            'metadata': {
              'agentOutcome': outcome,
              'resultCode': 'SUCCESS_CONFIRMED',
            },
          });
          await tester.pumpWidget(page(unreported, awaiting: false));
          await tester.pump();
          expect(find.byType(CallReceiptCard), findsNothing, reason: outcome);
          expect(find.text('通话已结束，结果待核实'), findsOneWidget);
        }

        final reportedCompleted = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'COMPLETED',
          'metadata': {'agentOutcome': 'SUCCESS'},
        });
        await tester.pumpWidget(page(reportedCompleted, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsOneWidget);
        expect(find.text('通话已结束，结果待核实'), findsNothing);

        final trustedLiveFinal = CallReceipt(
          attemptId: 'synthetic-attempt',
          status: 'COMPLETED',
          metadata: {'physicalTerminalOnly': 'true', 'liveFinalResult': 'true'},
        );
        await tester.pumpWidget(page(trustedLiveFinal, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsNothing);
        expect(find.text('通话已结束，结果待核实'), findsOneWidget);

        final physicalWithHeuristicFailure = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'CALL_COMPLETED',
          'detail': '任务未完成，仍需业务结果确认',
        });
        await tester.pumpWidget(
          page(physicalWithHeuristicFailure, awaiting: false),
        );
        await tester.pump();
        expect(find.text('通话已结束，结果待核实'), findsOneWidget);
        expect(find.byType(CallReceiptCard), findsNothing);

        final priorPhysical = CallReceipt.fromResult({
          'callAttemptId': 'older-attempt',
          'status': 'CALL_COMPLETED',
        });
        await tester.pumpWidget(
          page(receipt, awaiting: true, previous: priorPhysical),
        );
        await tester.pump();
        expect(find.text('正在确认通话结果'), findsOneWidget);
        expect(find.text('通话已结束，结果待核实'), findsOneWidget);
        expect(find.byType(CallReceiptCard), findsNothing);

        final reported = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'UNCLEAR',
          'detail': '商家未确认订位',
          'metadata': {'agentOutcome': 'UNCLEAR'},
        });
        await tester.pumpWidget(page(reported, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsOneWidget);
        expect(find.text('通话已结束，结果待核实'), findsNothing);
        expect(find.text('正在确认通话结果'), findsNothing);
        expect(find.text('· 正在整理通话结果'), findsNothing);

        final failed = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'CALL_FAILED',
          'detail': '线路接通失败',
        });
        await tester.pumpWidget(page(failed, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsOneWidget);
        expect(find.text('通话已结束，结果待核实'), findsNothing);

        final technicalFailure = CallReceipt.fromResult({
          'callAttemptId': 'synthetic-attempt',
          'status': 'CALL_COMPLETED',
          'detail': '外呼通道异常',
          'metadata': {'resultCode': 'MODEL_ERROR'},
        });
        await tester.pumpWidget(page(technicalFailure, awaiting: false));
        await tester.pump();
        expect(find.byType(CallReceiptCard), findsOneWidget);
        expect(find.text('通话已结束，结果待核实'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$platform original result rows and billing for all outcomes', (
      tester,
    ) async {
      for (final (outcome, code, title, status) in [
        ('SUCCESS', '', '任务完成', '✓任务完成'),
        ('FAILED', '', '任务失败', '未完成'),
        ('', 'MODEL_ERROR', '任务失败', '执行异常'),
        ('UNCLEAR', '', '任务未完成', '未完成'),
      ]) {
        final receipt = committedReceipt({
          'status': code.isEmpty ? 'COMPLETED' : 'FAILED',
          'metadata': {'agentOutcome': outcome, 'resultCode': code},
          'receiptFields': [
            {'key': 'target', 'label': '餐厅', 'value': '合成餐厅'},
          ],
          'billingSummary': {
            'billingSessionId': 'synthetic',
            'billingState': 'SETTLED',
            'displayDurationSeconds': 12,
            'firstMinutePoints': 5,
            'blockDurationMs': 10000,
            'blockPoints': 2,
            'chargedPoints': 0,
            'remainingPoints': 12345,
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.text(status), findsOneWidget);
        final heading = tester.widget<Text>(find.text(title));
        expect(heading.style?.fontSize, 14);
        expect(heading.style?.height, 18 / 14);
        final shell = find
            .descendant(
              of: find.byType(CallReceiptCard),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).gradient != null,
              ),
            )
            .first;
        final container = tester.widget<Container>(shell);
        expect(tester.getSize(shell).width, 280);
        expect(
          container.padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(16));
        expect(
          (decoration.gradient! as LinearGradient).colors,
          outcome == 'SUCCESS'
              ? [const Color(0xFFEDFAF0), const Color(0xFFD6F5DC)]
              : [const Color(0xFFFFF1F0), const Color(0xFFFFDAD6)],
        );
        expect(find.text('积分结算'), findsNothing);
        for (final label in ['计费时长', '模型费率', '扣除积分', '剩余积分']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('12 秒'), findsOneWidget);
        expect(find.text('首分钟 5，之后每 10 秒 2'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text('12,345'), findsOneWidget);
        final label = tester.widget<Text>(find.text('餐厅'));
        expect(label.style?.color, const Color(0xFF666666));
        final value = tester.widget<Text>(find.text('合成餐厅'));
        expect(value.maxLines, 2);
        expect(value.overflow, TextOverflow.ellipsis);
        expect(value.style?.color, const Color(0xFF333333));
        expect(value.style?.fontWeight, FontWeight.w600);
        expect(value.textAlign, TextAlign.right);
        expect(
          tester.getTopLeft(find.text('合成餐厅')).dx -
              tester.getTopRight(find.text('餐厅')).dx,
          closeTo(12, .01),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      '$platform narrow large-text success without invented billing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                  width: 240,
                  child: CallReceiptCard(
                    receipt: CallReceipt.fromResult({
                      'status': 'COMPLETED',
                      'targetName': '合成酒店',
                      'metadata': {
                        'sceneType': 'HOTEL_BOOKING',
                        'agentOutcome': 'SUCCESS',
                      },
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('任务完成'), findsOneWidget);
        expect(find.text('✓任务完成'), findsOneWidget);
        expect(find.text('酒店'), findsOneWidget);
        expect(find.text('扣除积分'), findsNothing);
        expect(find.text('剩余积分'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$platform booking failure keeps short reason and billing', (
      tester,
    ) async {
      for (final (code, reason) in [
        ('NO_ANSWER', '商家无人接听'),
        ('MODEL_ERROR', '模型服务异常'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: CallReceiptCard(
                receipt: CallReceipt.fromResult({
                  'status': 'FAILED',
                  'headline': '通话已结束',
                  'detail': reason,
                  'targetName': '合成餐厅',
                  'metadata': {
                    'sceneType': 'FOOD_ORDERING',
                    'resultCode': code,
                  },
                  'billingSummary': {
                    'billingSessionId': 'synthetic',
                    'billingState': 'SETTLED',
                    'chargedPoints': 0,
                    'remainingPoints': 900,
                  },
                }),
              ),
            ),
          ),
        );
        expect(find.text('任务失败'), findsOneWidget);
        expect(find.text('通话已结束'), findsNothing);
        expect(find.text('联系人'), findsNothing);
        expect(find.text(reason), findsOneWidget);
        expect(tester.widget<Text>(find.text(reason)).style?.fontSize, 13);
        expect(find.text('扣除积分'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      '$platform booking failure uses safe short fallback without status row',
      (tester) async {
        const diagnostic = '挂断原因 (terminationCause=SYSTEM_STOP)';
        for (final (headline, expected) in [
          ('订位未获确认', '订位未获确认'),
          ('通话已结束', '未完成'),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: CallReceiptCard(
                  receipt: CallReceipt.fromResult({
                    'status': 'FAILED',
                    'headline': headline,
                    'detail': diagnostic,
                    'metadata': {
                      'sceneType': 'RESTAURANT_BOOKING',
                      'agentOutcome': 'FAILED',
                      'agentReason': diagnostic,
                    },
                  }),
                ),
              ),
            ),
          );
          expect(find.text('任务失败'), findsOneWidget);
          final reasonText = find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == expected,
          );
          expect(reasonText, findsOneWidget);
          expect(tester.widget<Text>(reasonText).style?.fontSize, 13);
          expect(find.text('状态'), findsNothing);
          expect(find.textContaining('terminationCause'), findsNothing);
        }
      },
    );
  }
}
