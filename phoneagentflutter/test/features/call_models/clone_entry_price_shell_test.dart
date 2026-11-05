import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import '../../../tool/previews/shell_preview.dart';
import '../../support/pump_ui_transitions.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform formal model page and voice sheet show selected model quote',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(const ShellPreviewPage());
          await tester.pumpUntilUiSettled();
          Future<void> tapKey(String key) async {
            final target = find.byKey(ValueKey(key));
            if (target.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                target,
                160,
                scrollable: find.byType(Scrollable).last,
              );
            }
            await tester.ensureVisible(target);
            await tester.pumpUntilUiSettled();
            await tester.tap(target);
            await tester.pumpUntilUiSettled();
          }

          await tapKey('tab-3');
          await tapKey('settings-models');
          expect(find.bySemanticsLabel('声音克隆，650积分'), findsOneWidget);
          expect(find.text('300'), findsNothing);
          await tapKey('model-DOUBAO_SEEDUPLEX_3_0');
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('model-create-clone')),
            -180,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpUntilUiSettled();
          expect(find.bySemanticsLabel('声音克隆，900积分'), findsOneWidget);
          expect(find.bySemanticsLabel('声音克隆，650积分'), findsNothing);
          await tapKey('voices-DOUBAO_SEEDUPLEX_3_0');
          expect(
            find.descendant(
              of: find.byType(CallVoicesPage),
              matching: find.bySemanticsLabel('声音克隆，900积分'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
