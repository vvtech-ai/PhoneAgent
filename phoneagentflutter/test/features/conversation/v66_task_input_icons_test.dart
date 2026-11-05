import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_task_input_corner_icon.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform uses original task input icons and collapse action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationComposer(
                voiceMode: false,
                canSend: true,
                modelName: '测试模型',
                onToggle: () {},
                onSend: (_) => false,
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        );
        expect(find.text('输入任务内容'), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_voice_rounded), findsOneWidget);
        expect(find.byIcon(Icons.mic), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '第一行\n第二行',
        );
        await tester.pumpAndSettle();
        final expand = find.byKey(const ValueKey('task-input-expand'));
        expect(expand, findsOneWidget);
        expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
        expect(
          find.descendant(
            of: expand,
            matching: find.byType(NativeTaskInputCornerIcon),
          ),
          findsOneWidget,
        );
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(find.text('收回'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('task-input-collapse')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-input-summary')),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
