import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';
import 'package:phone_agent/features/calls/presentation/widgets/confirmation_billing_notice.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';

void main() {
  test(
    'rates and single/batch thresholds match fixed v65 including unknown balance',
    () {
      for (final entry in {
        'Qwen': 100,
        'DOUBAO': 110,
        'Seeduplex V3': 150,
      }.entries) {
        final rate = entry.value;
        final unknown = ConfirmationBillingSnapshot(modelTitle: entry.key);
        expect(unknown.firstMinute, rate);
        expect(unknown.notices(2), isEmpty);
        expect(
          ConfirmationBillingSnapshot(
            modelTitle: entry.key,
            availableBalance: rate - 1,
          ).notices(1).single,
          contains('不足以发起'),
        );
        expect(
          ConfirmationBillingSnapshot(
            modelTitle: entry.key,
            availableBalance: rate,
          ).notices(1).single,
          contains('不足2分钟'),
        );
        expect(
          ConfirmationBillingSnapshot(
            modelTitle: entry.key,
            availableBalance: rate * 2,
          ).notices(1),
          isEmpty,
        );
        expect(
          ConfirmationBillingSnapshot(
            modelTitle: entry.key,
            availableBalance: rate * 2 - 1,
          ).notices(2).first,
          '多路积分不足',
        );
      }
    },
  );
  test(
    'display metadata preserves exact alias ordinal and raw summary separators',
    () {
      final spec = <String, Object?>{
        'scene': 'restaurant',
        'targetName': '测试',
        'phoneNumber': '100',
        'primaryGoal': '合成',
        'summaryLines': ['  ', '时间：明天', '人数：2'],
        'recipientCount': 1,
      };
      final message = ConversationLiveMessages.confirmation('c', 'tool', spec)!;
      final expected = CallLaunchRequest(
        sessionId: 's',
        toolId: 'tool',
        commandId: 'c',
        ordinal: 2,
        spec: spec,
      );
      final actual = ConfirmationBillingRequest.forMessage('s', message, 2);
      expect(actual.aliases, expected.aliases);
      expect(actual, ConfirmationBillingRequest('s', expected.aliases));
    },
  );
  for (final width in [280.0, 390.0]) {
    testWidgets('read-only card has rates and batch notice at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallConfirmationCard(
              confirmation: CallConfirmation(
                targetName: '合成联系人',
                phoneNumber: '1,2',
                primaryGoal: '测试',
                summaryLines: [],
              ),
              billing: const ConfirmationBillingNotice(
                snapshot: ConfirmationBillingSnapshot(
                  modelTitle: 'Doubao',
                  availableBalance: 100,
                ),
                recipients: 2,
              ),
            ),
          ),
        ),
      );
      expect(find.text('接通后首分钟'), findsOneWidget);
      expect(find.text('之后每 6 秒'), findsOneWidget);
      expect(find.text('110积分'), findsOneWidget);
      expect(find.text('11积分'), findsOneWidget);
      expect(find.text('多路积分不足'), findsOneWidget);
      expect(find.text('确认执行'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final recipients in [1, 2]) {
      testWidgets(
        '$platform single/batch $recipients keeps original billing capsules',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SizedBox(
                    width: 248,
                    child: ConfirmationBillingNotice(
                      snapshot: const ConfirmationBillingSnapshot(
                        modelTitle: 'Qwen',
                        availableBalance: 150,
                      ),
                      recipients: recipients,
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final value in ['100积分', '10积分']) {
            final text = find.text(value);
            expect(text, findsOneWidget);
            final pill = tester.widget<Container>(
              find.ancestor(of: text, matching: find.byType(Container)).first,
            );
            final decoration = pill.decoration! as BoxDecoration;
            expect(decoration.color, const Color(0xFFEAF8EF));
            expect(decoration.borderRadius, BorderRadius.circular(999));
            expect(
              pill.padding,
              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            );
            final label = tester.widget<Text>(text);
            expect(label.softWrap, false);
            expect(label.style!.color, const Color(0xFF187A3A));
            expect(label.style!.fontWeight, FontWeight.bold);
          }
          expect(find.text('模型倍率已计入 · 未接通不扣 · 多路外呼每一路单独计费'), findsOneWidget);
          expect(
            find.text('多路积分不足'),
            recipients == 2 ? findsOneWidget : findsNothing,
          );
          if (recipients == 2) {
            final badge = tester.widget<Container>(
              find
                  .ancestor(
                    of: find.text('多路积分不足'),
                    matching: find.byType(Container),
                  )
                  .first,
            );
            expect(
              (badge.decoration! as BoxDecoration).color,
              const Color(0xFFFFF4D6),
            );
          }
          expect(find.byType(TextButton), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
