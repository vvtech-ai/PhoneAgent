import 'package:flutter/material.dart';
import '../../support/dial_permission_overrides.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dial_contact_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_contacts.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_contacts_controller.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_contact_suggestions.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';

class Dialer implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('shared suggestions select locally at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const policy = DialSuggestionPolicy(LpinyinContactDictionary());
      final snapshot = await PreviewDialContacts().load();
      DialContactSuggestion? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: DialContactSuggestions(
                query: '97',
                state: DialContactsState(
                  access: snapshot.access,
                  entries: policy.index(snapshot.rows),
                ),
                onSelect: (v) => selected = v,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('张三（合成）'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dial-suggestion:0')));
      expect(selected?.phone, '+12025550101');
      expect(tester.takeException(), isNull);
    });
  }
  for (final translation in [false, true]) {
    testWidgets(
      '${translation ? 'translation' : 'ordinary'} route fills correct country without dialing',
      (tester) async {
        final dialer = Dialer();
        final setup = TranslationSetupController();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...grantedDialPermissionOverrides(),
              dialContactsProvider.overrideWith((ref) {
                final controller = DialContactsController(
                  PreviewDialContacts(),
                  const DialSuggestionPolicy(LpinyinContactDictionary()),
                );
                controller.load();
                return controller;
              }),
              dialerControllerProvider.overrideWith(
                (ref) => DialerController(dialer),
              ),
              translationSetupProvider.overrideWith((ref) => setup),
            ],
            child: MaterialApp(
              home: translation
                  ? TranslationDialerRoute(number: '97', systemDialer: dialer)
                  : const DialerRoute(number: '97'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('dial-suggestion:0')),
        );
        await tester.tap(find.byKey(const ValueKey('dial-suggestion:0')));
        await tester.pumpAndSettle();
        expect(find.text('202 555 0101'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
        expect(dialer.calls, 0);
        if (translation) expect(setup.snapshot.country, 'US');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
