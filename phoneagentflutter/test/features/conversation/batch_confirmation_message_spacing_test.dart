import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_message_paragraph.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final description in [false, true]) {
        testWidgets(
          '$platform batch row spacing scale=$scale description=$description',
          (tester) async {
            tester.view.physicalSize = const Size(390, 1600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BatchConfirmationCard(
                              confirmation: BatchConfirmation(
                                snapshotId: 'synthetic',
                                version: 1,
                                title: '',
                                sections: const [
                                  BatchConfirmationSection('任务信息', [
                                    ConfirmationRow('目的', '合成评审'),
                                  ]),
                                ],
                                recipients: const [],
                                issues: const [],
                                rules: const [ConfirmationRow('时间', '合成时间')],
                                assistantText: description ? '合成说明' : '请补充信息',
                              ),
                            ),
                            ConversationMessageTile(
                              message: const ConversationMessage(
                                id: 'tail',
                                role: MessageRole.user,
                                text: '.',
                              ),
                              optionsEnabled: false,
                              onChoose: (_) {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              Rect panel(int index) => tester.getRect(
                find
                    .descendant(
                      of: find.byType(BatchConfirmationPanel).at(index),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              );
              expect(panel(1).top - panel(0).bottom, closeTo(10, .01));
              final tail = tester.getRect(
                find
                    .descendant(
                      of: find.byKey(const ValueKey('message:tail')),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              );
              if (description) {
                final paragraph = find.descendant(
                  of: find.byType(BatchConfirmationCard),
                  matching: find.byType(NativeMessageParagraph),
                );
                expect(paragraph, findsOneWidget);
                final bubble = tester.getRect(
                  find
                      .ancestor(
                        of: paragraph,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                );
                expect(bubble.top - panel(1).bottom, closeTo(10, .01));
                expect(tail.top - bubble.bottom, closeTo(10, .01));
                expect(find.bySemanticsLabel('合成说明'), findsOneWidget);
              } else {
                expect(tail.top - panel(1).bottom, closeTo(10, .01));
                expect(find.text('请补充信息'), findsNothing);
              }
              expect(find.text('执行任务'), findsNothing);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
