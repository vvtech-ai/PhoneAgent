import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/ocr_attachment_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_error_bubble.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'OCR processing motion reduced=$reduced and completion releases ticker',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final attachment = ValueNotifier(
          const OcrAttachment(
            id: 'synthetic',
            imageRef: '',
            anchor: 0,
            ordinal: 0,
          ),
        );
        addTearDown(attachment.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: ValueListenableBuilder<OcrAttachment>(
                    valueListenable: attachment,
                    builder: (context, value, _) => OcrAttachmentCard(
                      attachment: value,
                      image: const AssetImage(PreviewOcr.contactImage),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        expect(find.text('AI 思考过程'), findsOneWidget);
        expect(find.text('· AI 思考中'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.binding.hasScheduledFrame, !reduced);
        expect(tester.takeException(), isNull);
        attachment.value = attachment.value.finish(
          content: OcrContent(fullText: '合成识别文字'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NativeThinkingCard), findsNothing);
        expect(find.text('已识别图片文字'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final failure in OcrFailure.values) {
    testWidgets('OCR $failure failure is readable and replaces processing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const original = OcrAttachment(
        id: 'synthetic',
        imageRef: '',
        anchor: 0,
        ordinal: 0,
      );
      final attachment = original.finish(failure: failure);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: OcrAttachmentCard(
                  attachment: attachment,
                  image: const AssetImage(PreviewOcr.contactImage),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeErrorBubble), findsOneWidget);
      expect(find.text(attachment.failureMessage), findsOneWidget);
      expect(find.byType(NativeThinkingCard), findsNothing);
      expect(find.text('已识别图片文字'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
