import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_text_dock.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform keeps editing connection across line changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ConversationTextDock(
                controller: controller,
                enabled: true,
                onChanged: (_) {},
                onSend: () {},
                onAttachments: () {},
                onVoice: () {},
              ),
            ),
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '第一行');
      await tester.pump();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      final bottom = tester
          .getBottomLeft(
            find.byKey(const ValueKey('conversation-text-capsule')),
          )
          .dy;
      for (final text in [
        '第一行\n',
        '第一行\n第二行',
        '第一行\n第二行\n第三行',
        '自动折行文字' * 35,
        '第一行',
      ]) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(start: text.length - 3, end: text.length),
          ),
        );
        await tester.pump();
        expect(tester.state(find.byType(EditableText)), same(editor));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(tester.testTextInput.isVisible, isTrue);
        expect(controller.selection.extentOffset, text.length);
        expect(
          controller.value.composing,
          TextRange(start: text.length - 3, end: text.length),
          reason: text,
        );
        expect(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('conversation-text-capsule')),
              )
              .dy,
          bottom,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
