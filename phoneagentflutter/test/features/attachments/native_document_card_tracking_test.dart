import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform document tracking ignores ambient theme at $scale',
        (tester) async {
          Future<void> render(double ambient) => tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(letterSpacing: ambient),
                    child: const Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 308,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NativeDocumentCard(
                              files: [
                                UserDocumentFile('合成任务资料.docx', charCount: 120),
                                UserDocumentFile(
                                  '合成迁移演练用联系人与参会时间安排清单.xlsx',
                                  charCount: 40,
                                  truncated: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await render(7);
          final richTexts = find.descendant(
            of: find.byType(NativeDocumentCard),
            matching: find.byType(RichText),
          );
          expect(richTexts, findsNWidgets(8));
          for (final text in tester.widgetList<RichText>(richTexts)) {
            expect(text.text.style!.letterSpacing, closeTo(.5 * scale, .001));
          }
          final initial = tester.getSize(find.byType(NativeDocumentCard));
          final fileRect = tester.getRect(find.text('合成任务资料.docx'));
          expect(tester.takeException(), isNull);
          await render(-1);
          expect(tester.getSize(find.byType(NativeDocumentCard)), initial);
          expect(tester.getRect(find.text('合成任务资料.docx')), fileRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
