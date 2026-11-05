import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/account_confirmation_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'ordinary Chinese IME composes and commits before confirmation $platform',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAccountConfirmation(context, '');
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final input = find.byKey(const Key('account-confirmation-input'));
        final submit = find.byKey(const Key('account-confirmation-submit'));
        final field = tester.widget<TextField>(input);
        expect(field.keyboardType, TextInputType.text);
        expect(field.autocorrect, isFalse);
        expect(
          tester.testTextInput.setClientArgs!['enableSuggestions'],
          isTrue,
        );
        expect(
          tester.testTextInput.setClientArgs!['inputType'],
          containsPair('name', 'TextInputType.text'),
        );

        for (final text in ['que ren zhu xiao', '确认注销']) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange(start: 0, end: text.length),
            ),
          );
          await tester.pump();
          expect(field.controller!.text, text);
          expect(field.controller!.value.composing.isCollapsed, isFalse);
          expect(tester.widget<TextButton>(submit).onPressed, isNull);
        }
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '确认注销',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );
        await tester.pump();
        expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
