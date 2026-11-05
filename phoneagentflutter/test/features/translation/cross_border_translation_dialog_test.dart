import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_confirmation_dialog.dart';
import 'package:phone_agent/features/translation/presentation/widgets/cross_border_translation_confirmation.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final action in [
      'continue',
      'cancel',
      'back',
      'barrier',
      'stale',
      'invalid',
    ]) {
      testWidgets('$platform shared cross-border dialog $action', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var revision = 0, active = true;
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await confirmCrossBorderTranslationCall(
                      context,
                      callerCountryIso: 'CN',
                      calleeCountryIso: 'US',
                      isCurrent: () => active,
                      readSnapshot: () => revision,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(NativeConfirmationDialog), findsOneWidget);
        expect(find.text('跨境通话质量提示'), findsOneWidget);
        expect(find.text('当前为跨境实时翻译通话，可能出现信号不稳定或延迟较大的情况。'), findsOneWidget);
        expect(result, isNull);
        if (action == 'stale') revision++;
        if (action == 'invalid') active = false;
        if (action == 'back') {
          await tester.binding.handlePopRoute();
        } else if (action == 'barrier') {
          await tester.tapAt(const Offset(4, 4));
        } else {
          await tester.tap(
            find.byKey(
              Key(
                action == 'cancel'
                    ? 'cross-border-cancel'
                    : 'cross-border-continue',
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(result, action == 'continue');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
