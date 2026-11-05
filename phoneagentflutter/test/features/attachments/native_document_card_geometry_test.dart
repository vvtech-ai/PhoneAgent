import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform document border preserves actual insets at $scale',
        (tester) async {
          var parsing = false;
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 308,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NativeDocumentCard(
                                parsing: parsing,
                                files: const [
                                  UserDocumentFile(
                                    '合成任务资料.docx',
                                    charCount: 120,
                                  ),
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
                    );
                  },
                ),
              ),
            ),
          );
          final card = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color ==
                    const Color(0xFFF2F7FF),
          );
          final icon = find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.constraints?.maxWidth == 34,
          );
          final rect = tester.getRect(card);
          expect(
            tester.getRect(find.text('已上传任务资料')).left - rect.left,
            closeTo(14, .01),
          );
          expect(tester.getRect(icon.first).left - rect.left, closeTo(14, .01));
          expect(
            tester.getRect(find.text('合成任务资料.docx')).left - rect.left,
            closeTo(58, .01),
          );
          expect(tester.getRect(find.byType(Divider)).width, closeTo(308, .01));
          expect(find.text('Excel 工作簿 · 已解析 40 字 · 内容已截断'), findsOneWidget);
          expect(tester.takeException(), isNull);
          change(() => parsing = true);
          await tester.pump();
          expect(find.text('正在上传任务资料'), findsOneWidget);
          expect(find.text('2 个文件'), findsOneWidget);
          expect(
            rect.right - tester.getRect(find.text('2 个文件')).right,
            closeTo(14, .01),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
