import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [276.0, 390.0]) {
      testWidgets(
        '$platform at $width single and multiple share native width',
        (tester) async {
          final sizes = <double>[];
          for (final count in [1, 3]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: CallConfirmationCard(
                        confirmation: CallConfirmation(
                          targetName: '合成目标',
                          phoneNumber: '000',
                          primaryGoal: '仅布局验证',
                          summaryLines: [],
                          recipientCount: count,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final card = find
                .descendant(
                  of: find.byType(CallConfirmationCard),
                  matching: find.byType(Container),
                )
                .first;
            sizes.add(tester.getSize(card).width);
            expect(sizes.last, width < 280 ? width : 280);
            // The timeline owns recorded prose; a bare card does not invent it.
            expect(find.text('请确认以上任务内容，是否现在拨打？'), findsNothing);
            expect(tester.takeException(), isNull);
          }
          expect(sizes.first, sizes.last);
        },
      );
    }
  }
}
