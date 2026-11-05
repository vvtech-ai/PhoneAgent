import 'dart:async';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
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
      final ordinaryAndTranslation = tester.widgetList<DialerPage>(
        find.byType(DialerPage, skipOffstage: false),
      );
      expect(ordinaryAndTranslation.last.state.input, '123');
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

    testWidgets(
      'covered preparation releases late session without starting on $platform',
      (tester) async {
        final gate = Completer<TranslationSessionController>();
        final setup = TranslationSetupController()
          ..directory(syntheticTranslationDirectory)
          ..prompt(false);
        final fixture = PreviewTranslationSession();
        var prepares = 0, released = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationSetupProvider.overrideWith((_) => setup),
              networkAvailabilitySourceProvider.overrideWithValue(
                const UnknownNetworkAvailability(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: TranslationDialerRoute(
                preview: true,
                number: '+12025550123',
                sessionBinding: TranslationDialSessionBinding(
                  create: (_) {
                    prepares++;
                    return gate.future;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.widget<DialerPage>(find.byType(DialerPage)).onDial();
        await tester.pumpAndSettle();
        expect(prepares, 1);
        final context = tester.element(find.byType(DialerPage));
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('covered')),
          ),
        );
        await tester.pumpAndSettle();
        final controller = TranslationSessionController(
          backend: fixture,
          mediaFactory: fixture.media,
          loadLanguages: fixture.languages,
          request: PreviewTranslationSession.request,
          onReleased: () => released++,
        );
        gate.complete(controller);
        await tester.pumpAndSettle();
        expect(controller.mounted, isFalse);
        expect(released, 1);
        expect(fixture.creates, 0);
        expect(find.text('covered'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('country selection returns with number draft on $platform', (
      tester,
    ) async {
      final page = await open(tester);
      page.onCountry();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        '65',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-country-SG')));
      await tester.pumpAndSettle();
      final returned = tester.widget<DialerPage>(find.byType(DialerPage));
      expect(returned.state.input, '123');
      expect(returned.state.countryIso, 'SG');
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
      page.onDial();
      await tester.pumpAndSettle();
      expect(find.byType(TranslationDialerRoute), findsNothing);
      expect(find.byType(DialerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
