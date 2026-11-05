import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/dial_country.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_country_page.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_country_index.dart';

void main() {
  test('native effective catalog remains four countries with G20 subset', () {
    expect(dialCountries.map((e) => e.iso), ['CN', 'JP', 'SG', 'US']);
    expect(dialCountries.where((e) => e.inG20).map((e) => e.iso), [
      'CN',
      'JP',
      'US',
    ]);
    expect(dialCountries.map((e) => e.section), ['C', 'J', 'S', 'U']);
    expect(dialCountry('jp')!.matches('r i b e n'), isTrue);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform grouped flags index feedback and search at 2x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DialCountryPage(selected: 'JP', location: Text('合成位置状态')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(7));
      expect(find.byKey(const Key('dial-country-g20-JP')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dial-index-U')));
      await tester.pump();
      expect(find.byKey(const Key('dial-index-feedback')), findsOneWidget);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      expect(scroll.position.pixels, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.byKey(const Key('dial-index-feedback')), findsNothing);
      await tester.drag(find.byType(DialCountryIndex), const Offset(0, -50));
      await tester.pump();
      expect(find.byKey(const Key('dial-index-feedback')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'r i b e n',
      );
      await tester.pump();
      expect(find.byType(DialCountryIndex), findsNothing);
      expect(find.text('日本'), findsOneWidget);
      expect(find.text('中国'), findsNothing);
      expect(find.text('合成位置状态'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'zzzz',
      );
      await tester.pump();
      expect(find.text('暂无匹配的国家或地区'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets('G20 choice returns the same ISO as normal country row', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const DialCountryPage(selected: 'CN'),
                  ),
                );
              },
              child: const Text('选择'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dial-country-g20-JP')));
    await tester.pumpAndSettle();
    expect(chosen, 'JP');
    expect(find.byType(DialCountryPage), findsNothing);
  });
}
