import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_country_page.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    Future<DialerPage> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openDialer(context, preview: true, number: '123'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return tester.widget<DialerPage>(find.byType(DialerPage));
    }

    testWidgets('covered dialer rejects old close and input on $platform', (
      tester,
    ) async {
      final page = await open(tester);
      page.onCountry();
      await tester.pumpAndSettle();
      page.onDigit('9');
      page.onDelete();
      page.onClear();
      page.onClose();
      await tester.pumpAndSettle();
      expect(find.byType(DialCountryPage), findsOneWidget);
      expect(
        tester
            .widget<DialerPage>(find.byType(DialerPage, skipOffstage: false))
            .state
            .input,
        '123',
      );
    });

    testWidgets('old country entry cannot push twice on $platform', (
      tester,
    ) async {
      final page = await open(tester);
      page.onCountry();
      await tester.pumpAndSettle();
      page.onCountry();
      await tester.pumpAndSettle();
      expect(find.byType(DialCountryPage, skipOffstage: false), findsOneWidget);
    });

    testWidgets('unified entry opens once and closes directly on $platform', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('实时翻译配置'), findsNothing);
      final reopen = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'open', skipOffstage: false),
          )
          .onPressed!;
      reopen();
      await tester.pumpAndSettle();
      expect(
        find.byType(TranslationDialerRoute, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(DialerPage, skipOffstage: false), findsOneWidget);
      tester.widget<DialerPage>(find.byType(DialerPage)).onClose();
      await tester.pumpAndSettle();
      expect(find.byType(TranslationDialerRoute), findsNothing);
      expect(find.byType(DialerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('platform back closes the only dialer on $platform', (
      tester,
    ) async {
      await open(tester);
      if (platform == TargetPlatform.iOS) {
        final rect = tester.getRect(find.byType(DialerPage));
        await tester.dragFrom(
          Offset(rect.left + 1, rect.center.dy),
          Offset(rect.width * .8, 0),
        );
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(DialerPage), findsNothing);
      expect(find.byType(TranslationDialerRoute), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposed dialer actions are inert on $platform', (
      tester,
    ) async {
      final page = await open(tester);
      page.onClose();
      await tester.pumpAndSettle();
      page.onDigit('9');
      page.onClear();
      page.onCountry();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
