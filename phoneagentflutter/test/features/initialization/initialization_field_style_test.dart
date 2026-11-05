import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/initialization/presentation/widgets/initialization_fields.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform narrow large fields grow without clipping', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: InitializationIdentityFields(
                  draft: const IdentityDraft(),
                  busy: false,
                  onName: (_) {},
                  onGender: (_) {},
                  onPhone: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      for (final field in find.byType(TextField).evaluate()) {
        expect(
          tester.getSize(find.byWidget(field.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.ensureVisible(find.byKey(const ValueKey('init-phone')));
      await tester.enterText(
        find.byKey(const ValueKey('init-phone')),
        '12345678901',
      );
      expect(find.text('12345678901'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform explicit field borders selection and busy filters', (
      tester,
    ) async {
      var phone = '';
      var selections = 0;
      Future<void> render(bool busy) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: InitializationIdentityFields(
              draft: const IdentityDraft(),
              busy: busy,
              onName: (_) {},
              onGender: (_) => selections++,
              onPhone: (value) => phone = value,
            ),
          ),
        ),
      );
      await render(false);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.decoration!.enabledBorder, isNotNull);
        expect(
          field.decoration!.enabledBorder!.borderSide.color,
          const Color(0x213C3C43),
        );
        expect(
          field.decoration!.disabledBorder!.borderSide.color,
          const Color(0x213C3C43),
        );
        expect(
          field.decoration!.focusedBorder!.borderSide.color,
          const Color(0xFF0A84FF),
        );
        expect(field.decoration!.hintStyle!.fontSize, 13);
        expect(field.style!.letterSpacing, 0);
      }
      final selected = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '不透露'),
      );
      expect(selected.style!.side!.resolve({})!.color, const Color(0x520A84FF));
      expect(
        selected.style!.backgroundColor!.resolve({}),
        const Color(0x1A0A84FF),
      );
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, '男')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.enterText(
        find.byKey(const ValueKey('init-phone')),
        '123abc456789012',
      );
      expect(phone, '12345678901');
      await tester.tap(find.text('男'));
      expect(selections, 1);
      await render(true);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
        expect(field.decoration!.fillColor, const Color(0xFFF3F4F6));
      }
      await tester.tap(find.text('女'));
      expect(selections, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
