import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform voice close named and old callback cannot close new sheet',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        Future<void> tap(String name) async {
          final finder = find.byKey(ValueKey(name));
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              160,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await Scrollable.ensureVisible(
            tester.element(finder),
            alignment: .35,
          );
          await tester.pumpUntilUiSettled();
          await tester.tap(finder);
          await tester.pumpUntilUiSettled();
        }

        try {
          await tester.pumpWidget(const ShellPreviewPage());
          await tester.pumpUntilUiSettled();
          await tap('tab-3');
          await tap('settings-models');
          await tap('voices-QWEN_OMNI_PLUS');
          final close = find.byKey(const ValueKey('backFromVoiceIdentity'));
          final old = tester.widget<IconButton>(close).onPressed!;
          final node = tester.getSemantics(find.bySemanticsLabel('关闭音色选择'));
          expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(tester.getSize(close), const Size(48, 48));
          old();
          old();
          await tester.pumpUntilUiSettled();
          expect(find.byType(CallVoicesPage), findsNothing);
          await tap('voices-QWEN_OMNI_PLUS');
          old();
          await tester.pumpUntilUiSettled();
          expect(find.byType(CallVoicesPage), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('关闭音色选择'));
          await tester.pumpUntilUiSettled();
          expect(find.byType(CallVoicesPage), findsNothing);
          expect(
            find.byKey(const ValueKey('backFromVoiceModel')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpUntilUiSettled();
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
