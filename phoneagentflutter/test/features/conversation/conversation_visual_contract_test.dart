import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_keyboard_mode_icon.dart';

void main() {
  testWidgets('draft survives input mode toggle and rejected submission', (
    tester,
  ) async {
    var voice = false, accepted = false;
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ConversationComposer(
              voiceMode: voice,
              canSend: true,
              modelName: '合成模型',
              onToggle: () => setState(() => voice = !voice),
              onSend: (_) {
                attempts++;
                return accepted;
              },
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        ),
      ),
    );
    final input = find.byKey(const ValueKey('conversation-input'));
    await tester.enterText(input, '尚未提交的需求');
    await tester.tap(find.byKey(const ValueKey('toggle-voice')));
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const ValueKey('toggle-text')));
    await tester.pumpUntilUiSettled();
    expect(tester.widget<TextField>(input).controller!.text, '尚未提交的需求');
    await tester.tap(find.byKey(const ValueKey('send-text')));
    await tester.pump();
    expect(attempts, 1);
    expect(tester.widget<TextField>(input).controller!.text, '尚未提交的需求');
    accepted = true;
    await tester.tap(find.byKey(const ValueKey('send-text')));
    await tester.pump();
    expect(attempts, 2);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
  });

  testWidgets('header uses measured title, status and control geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ConversationHeader(onClose: () {}, status: '文字输入'),
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('PhoneAgent'));
    expect(title.style!.fontSize, 30);
    expect(title.style!.fontWeight, FontWeight.w800);
    expect(
      tester.getSize(find.byKey(const ValueKey('close-conversation'))),
      const Size(52, 52),
    );
    expect(tester.getTopLeft(find.text('PhoneAgent')).dx, 18);
    expect(tester.getTopLeft(find.text('文字输入')).dx, 54);
    expect(
      tester.getSize(find.byType(ConversationHeader)).height,
      greaterThanOrEqualTo(114),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared composer uses native glyphs and clears accepted input', (
    tester,
  ) async {
    var voice = true;
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomCenter,
              child: ConversationComposer(
                voiceMode: voice,
                canSend: true,
                modelName: '测试模型',
                onToggle: () => setState(() => voice = !voice),
                onSend: (text) {
                  sent.add(text);
                  return true;
                },
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    expect(
      tester.getSize(find.byKey(const ValueKey('conversation-voice-button'))),
      const Size(56, 56),
    );
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(NativeKeyboardModeIcon), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_voice_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-text')));
    await tester.pumpUntilUiSettled();
    final input = find.byKey(const ValueKey('conversation-input'));
    await tester.enterText(input, '仅整理文字');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-text')));
    await tester.pump();
    expect(sent, ['仅整理文字']);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('send-text')))
          .onPressed,
      isNull,
    );
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
