import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/presentation/pages/ocr_preview_page.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/ocr_attachment_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_timeline_attachment.dart';

void main() {
  testWidgets(
    'timeline clamps anchors and preserves selection order at equal boundary',
    (tester) async {
      final widgets = withTimelineAttachments(
        [const Text('m0'), const Text('m1')],
        const [
          ConversationTimelineAttachment('a', -1, Text('a')),
          ConversationTimelineAttachment('b', 1, Text('b')),
          ConversationTimelineAttachment('c', 1, Text('c')),
          ConversationTimelineAttachment('d', 99, Text('d')),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: Column(children: widgets)));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data);
      expect(texts, ['a', 'm0', 'b', 'c', 'm1', 'd']);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'OCR card long fields expand/collapse fits $width at $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final content = OcrContent(
            fullText: '${'长文' * 35}结尾',
            fields: const [OcrField('很长的字段名称', '合成长内容没有电话呼叫按钮也没有编辑入口')],
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: OcrAttachmentCard(
                      attachment: OcrAttachment(
                        id: 'one',
                        imageRef: '',
                        anchor: 0,
                        ordinal: 0,
                        status: OcrStatus.success,
                        content: content,
                      ),
                      image: const AssetImage(PreviewOcr.contactImage),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpUntilUiSettled();
          expect(tester.takeException(), isNull);
          expect(find.text('图片暂不可用'), findsNothing);
          expect(find.text('展开'), findsOneWidget);
          expect(find.text(content.fullText), findsNothing);
          await tester.ensureVisible(find.text('展开'));
          await tester.tap(find.text('展开'));
          await tester.pumpUntilUiSettled();
          expect(find.text(content.fullText), findsOneWidget);
          await tester.ensureVisible(find.text('收起'));
          await tester.tap(find.text('收起'));
          await tester.pumpUntilUiSettled();
          expect(find.text(content.fullText), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'MOCK picker cancel, success, failed reselect and back preserve original page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OcrPreviewPage(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.bySemanticsLabel('添加图片'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('取消选择'));
      await tester.pumpUntilUiSettled();
      expect(find.byType(OcrAttachmentCard), findsNothing);
      await tester.tap(find.bySemanticsLabel('添加图片'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('合成名片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpUntilUiSettled();
      expect(find.text('已识别图片文字'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('添加图片'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('云端保存失败'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpUntilUiSettled();
      expect(find.text('图片保存失败，请重新选择图片'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-conversation')));
      await tester.pumpUntilUiSettled();
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
