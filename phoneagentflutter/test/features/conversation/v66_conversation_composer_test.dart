import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform owner removal closes expanded draft', (
      tester,
    ) async {
      var open = true;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return open
                    ? ConversationComposer(
                        voiceMode: false,
                        canSend: true,
                        modelName: '测试模型',
                        onToggle: () {},
                        onSend: (_) => false,
                        onNotice: (_) {},
                        onModels: () {},
                      )
                    : const Text('新账号首页');
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '原账号第一行\n第二行',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-input-expand')));
      await tester.pumpAndSettle();
      change(() => open = false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-expanded-input')),
        findsNothing,
      );
      expect(find.text('新账号首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform expanded editor fits keyboard and sends only once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      var canSend = false;
      var accepted = false;
      final sent = <String>[];
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: StatefulBuilder(
                builder: (context, setState) {
                  change = setState;
                  return ConversationComposer(
                    voiceMode: false,
                    canSend: canSend,
                    modelName: '测试模型',
                    onToggle: () {},
                    onNotice: (_) {},
                    onModels: () {},
                    onSend: (text) {
                      sent.add(text);
                      return accepted;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '第一行\n第二行',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-input-expand')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('conversation-expanded-sheet'));
      expect(tester.getSize(sheet).height, closeTo((568 - 300) * .85, .01));
      final send = find.byKey(const ValueKey('send-expanded-text'));
      expect(tester.getRect(send).bottom, lessThanOrEqualTo(268));
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      change(() => canSend = true);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sent, ['第一行\n第二行']);
      expect(sheet, findsOneWidget);
      accepted = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sent, ['第一行\n第二行', '第一行\n第二行']);
      expect(sheet, findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('conversation-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$platform preserves newlines and edits while send is blocked',
      (tester) async {
        var sends = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationComposer(
                voiceMode: false,
                canSend: false,
                modelName: '测试模型',
                onToggle: () {},
                onSend: (_) {
                  sends++;
                  return true;
                },
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        );
        final field = find.byKey(const ValueKey('conversation-input'));
        final input = tester.widget<TextField>(field);
        expect(input.enabled, isNot(false));
        expect(input.minLines, 1);
        expect(input.maxLines, 5);
        expect(input.textInputAction, TextInputAction.newline);
        await tester.enterText(field, '第一行\n第二行\n第三行');
        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pumpAndSettle();
        expect(input.controller!.text, '第一行\n第二行\n第三行');
        expect(sends, 0);
        expect(find.byKey(const ValueKey('task-input-expand')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('task-input-expand')));
        await tester.pumpAndSettle();
        final expanded = find.byKey(
          const ValueKey('conversation-expanded-input'),
        );
        final editor = tester.widget<TextField>(expanded);
        expect(editor.controller, same(input.controller));
        await tester.enterText(expanded, '编辑后第一行\n第二行');
        editor.controller!.selection = const TextSelection.collapsed(offset: 3);
        await tester.tap(find.byKey(const ValueKey('task-input-collapse')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-input-summary')),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(
          find.byKey(const ValueKey('conversation-input-summary')),
        );
        await tester.pump();
        expect(input.controller!.text, '编辑后第一行\n第二行');
        expect(input.controller!.selection.baseOffset, 3);
        expect(sends, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
