import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/account_entry_confirmation_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'historical entry content and input gate $platform',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAccountEntryConfirmation(
                      context,
                      '13800000000',
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
        expect(find.text('确认注销账号？'), findsOneWidget);
        expect(
          find.text('注销账号后，全部信息将会被移除，且无法找回。若确认注销，请在下方输入框输入“确认注销”。'),
          findsOneWidget,
        );
        expect(find.textContaining('当前账号', findRichText: true), findsOneWidget);
        expect(
          find.textContaining('138****0000', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('13800000000', findRichText: true),
          findsNothing,
        );
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(
          (dialog.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(30),
        );
        expect(dialog.elevation, 24);
        final input = find.byKey(const Key('account-confirmation-input'));
        final submit = find.byKey(
          const Key('account-entry-confirmation-submit'),
        );
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        await tester.enterText(input, '确认');
        await tester.pump();
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '确认注销',
            composing: TextRange(start: 0, end: 4),
          ),
        );
        await tester.pump();
        expect(tester.widget<TextButton>(submit).onPressed, isNull);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '确认注销',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );
        await tester.pump();
        expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
        expect(
          tester.widget<TextButton>(submit).style!.backgroundColor!.resolve({}),
          const Color(0xFFE65353),
        );
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(result, true);
        expect(find.byType(Dialog), findsNothing);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  testWidgets(
    'historical entry remains scrollable with keyboard and large text; cancel is always allowed',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 230),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAccountEntryConfirmation(
                    context,
                    '13800000000',
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
      await tester.ensureVisible(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('取消').hitTestable(), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, false);
      expect(tester.takeException(), isNull);
    },
  );
}
