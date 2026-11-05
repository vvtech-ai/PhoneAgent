import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/dial_country.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/native_dial_number_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('native dial header short large text and busy $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      var enabled = true, taps = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Builder(
                  builder: (_) {
                    rebuild = setState;
                    return NativeDialNumberHeader(
                      country: dialCountry('SG')!,
                      input: '12345678901234',
                      onCountry: enabled ? () => taps++ : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Image)), const Size(26, 18));
      final number = tester.widget<Text>(find.byKey(const Key('dial-number')));
      expect(number.style!.fontSize, greaterThanOrEqualTo(16.5));
      expect(number.maxLines, 1);
      expect(number.data!.replaceAll(' ', ''), '12345678901234');
      final country = find.bySemanticsLabel('选择国家或地区，新加坡，+65');
      expect(
        tester.getSemantics(country),
        matchesSemantics(
          label: '选择国家或地区，新加坡，+65',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(const Key('dial-country')));
      expect(taps, 1);
      rebuild(() => enabled = false);
      await tester.pump();
      expect(
        tester.widget<InkWell>(find.byKey(const Key('dial-country'))).onTap,
        isNull,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
