import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_route.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import '../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final receipt in [false, true]) {
      testWidgets(
        '$platform standalone App save cancel receipt=$receipt',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(393, 820);
          addTearDown(tester.view.reset);
          // No outer MaterialApp or workbench Navigator may mask the host bug.
          await tester.pumpWidget(const ShellPreviewPage());
          await tester.pumpUntilUiSettled();
          await tester.tap(find.byKey(const ValueKey('tab-2')));
          await tester.pumpUntilUiSettled();
          final entry = find.byKey(
            ValueKey(
              receipt ? 'conversation:mock-receipt-single' : 'call:translation',
            ),
          );
          await tester.ensureVisible(entry);
          await tester.pumpUntilUiSettled();
          await tester.tap(entry);
          await tester.pumpUntilUiSettled();
          final page = receipt
              ? find.byType(ConversationRoute)
              : find.byType(TranslationHistoryRoute);
          expect(page, findsOneWidget);
          final save = find.byKey(const ValueKey('recording-save'));
          await tester.ensureVisible(save);
          await tester.pumpUntilUiSettled();
          if (save.hitTestable().evaluate().isEmpty) {
            await tester.ensureVisible(save);
            await tester.pumpUntilUiSettled();
          }
          expect(save.hitTestable(), findsOneWidget);
          await tester.tap(save);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.text(receipt ? 'MOCK · 保存本次录音' : 'MOCK · 保存录音'),
            findsOneWidget,
          );
          expect(find.text('录音保存失败，请重试'), findsNothing);
          await tester.tap(find.text('取消保存'));
          await tester.pumpUntilUiSettled();
          expect(page, findsOneWidget);
          expect(find.text('录音已保存'), findsNothing);
          expect(find.text('录音保存失败，请重试'), findsNothing);
          expect(tester.widget<IconButton>(save).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpUntilUiSettled();
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
