import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_country_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform country selection is named and exits once at 2x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      String? result;
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const DialCountryPage(selected: 'SG'),
                    ),
                  );
                  completions++;
                },
                child: const Text('打开国家'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开国家'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('返回')),
        matchesSemantics(
          label: '返回',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'xjp',
      );
      await tester.pump();
      final row = find.byKey(const Key('dial-country-SG'));
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          label: '新加坡，+65',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      final oldTap = tester
          .widget<InkWell>(
            find.descendant(of: row, matching: find.byType(InkWell)),
          )
          .onTap!;
      oldTap();
      oldTap();
      await tester.pumpAndSettle();
      expect(result, 'SG');
      expect(completions, 1);
      expect(find.text('打开国家'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
