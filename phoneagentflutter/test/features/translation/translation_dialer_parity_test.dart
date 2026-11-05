import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_contact_suggestions_host.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_recent_host.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../../support/dial_permission_overrides.dart';
import '../../support/translation_directory_fixture.dart';

const directory = TranslationDirectory(
  version: 1,
  defaultCaller: 'zh',
  countries: [
    TranslationDirectoryCountry('CN', '+86', '中国', 'zh', [], '', ''),
    TranslationDirectoryCountry('JP', '+81', '日本', 'ja', [], '', ''),
    TranslationDirectoryCountry('GB', '+44', '英国', 'en', [], '', ''),
  ],
  models: [],
  languages: [
    TranslationDirectoryLanguage('zh', '中文', '', '', false),
    TranslationDirectoryLanguage('en', '英语', '', '', false),
    TranslationDirectoryLanguage('ja', '日语', '', '', false),
  ],
);

void main() {
  tearDown(dismissNativeNotice);
  testWidgets(
    'external configured country waits for directory before preparing',
    (tester) async {
      final gate = Completer<TranslationDirectory>();
      final setup = TranslationSetupController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...grantedDialPermissionOverrides(),
            translationSetupProvider.overrideWith((_) => setup),
            translationDirectoryProvider.overrideWith((_) => gate.future),
            translationAccessProvider.overrideWith((ref) {
              ref.watch(translationSetupProvider);
              return TranslationAccess(countryIso: 'US', forced: false);
            }),
          ],
          child: MaterialApp(
            home: TranslationDialerRoute(
              number: '+442079460000',
              systemDialer: _NoCall(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete(directory);
      await tester.pumpAndSettle();
      final state = tester.widget<DialerPage>(find.byType(DialerPage)).state;
      expect(state.countryIso, 'GB');
      expect(state.input, '2079460000');
      expect(setup.snapshot.country, 'GB');
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'CN country, contact and history keep Chinese with active model $platform',
      (tester) async {
        final setup = TranslationSetupController()
          ..directory(
            syntheticTranslationDirectory,
            callerCountryIso: 'CN',
            overseas: false,
          )
          ..country('US');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...grantedDialPermissionOverrides(),
              translationSetupProvider.overrideWith((_) => setup),
              translationDirectoryProvider.overrideWith(
                (_) async => syntheticTranslationDirectory,
              ),
              translationAccessProvider.overrideWith(
                (_) => const TranslationAccess(countryIso: 'CN', forced: false),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: TranslationDialerRoute(systemDialer: _NoCall()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(setup.snapshot.peer, 'en');
        tester.widget<DialerPage>(find.byType(DialerPage)).onCountry();
        await tester.pumpAndSettle();
        await tester.tap(find.text('CN').last);
        await tester.pumpAndSettle();
        expect(setup.snapshot.country, 'CN');
        expect(find.textContaining('中文 对方'), findsOneWidget);

        setup.country('US');
        await tester.pumpAndSettle();
        tester
            .widget<DialContactSuggestionsHost>(
              find.byType(DialContactSuggestionsHost),
            )
            .onSelect(
              const DialContactSuggestion(
                DialContactEntry(
                  DeviceContactRow(
                    contactId: 'synthetic-cn',
                    name: '中国合成联系人',
                    phone: '+8618000000001',
                  ),
                  [],
                  '+8618000000001',
                  '中国合成联系人',
                ),
              ),
            );
        await tester.pumpAndSettle();
        expect(
          tester.widget<DialerPage>(find.byType(DialerPage)).state.input,
          '18000000001',
        );
        expect(setup.snapshot.peer, 'zh');
        expect(find.textContaining('中文 对方'), findsOneWidget);
        setup.language('en', caller: false);
        setup.directory(
          syntheticTranslationDirectory,
          callerCountryIso: 'CN',
          overseas: false,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('英文 对方'), findsOneWidget);
        tester
            .widget<DialRecentHost>(find.byType(DialRecentHost))
            .onSelect(
              const DialRecentCall(
                id: 'synthetic-cn-history',
                phone: '+8618000000001',
                startedAtMillis: 1,
                source: DialRecentSource.app,
                countryIso: 'CN',
                callerLanguage: 'zh',
                peerLanguage: 'en',
              ),
            );
        await tester.pumpAndSettle();
        expect(setup.snapshot.peer, 'zh');
        expect(find.textContaining('中文 对方'), findsOneWidget);
        setup.prompt(false);
        tester.widget<DialerPage>(find.byType(DialerPage)).onDial();
        await tester.pumpAndSettle();
        expect(find.text('请选择不同的我方和对方语种'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('live contact and history JP entries update peer $platform', (
      tester,
    ) async {
      final setup = TranslationSetupController()..directory(directory);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...grantedDialPermissionOverrides(),
            translationSetupProvider.overrideWith((_) => setup),
            translationDirectoryProvider.overrideWith((_) async => directory),
            translationAccessProvider.overrideWith((ref) {
              ref.watch(translationSetupProvider);
              return TranslationAccess(countryIso: 'US', forced: false);
            }),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: TranslationDialerRoute(systemDialer: _NoCall()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final host = tester.widget<DialContactSuggestionsHost>(
        find.byType(DialContactSuggestionsHost),
      );
      host.onSelect(
        const DialContactSuggestion(
          DialContactEntry(
            DeviceContactRow(
              contactId: 'synthetic-jp',
              name: '日本合成联系人',
              phone: '+81334451111',
            ),
            [],
            '+81334451111',
            '日本合成联系人',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(setup.snapshot.country, 'JP');
      expect(setup.snapshot.peer, 'ja');
      setup.language('en', caller: false);
      await tester.pumpAndSettle();
      expect(
        setup.snapshot.peer,
        'en',
        reason: 'Explicit language choice is not a location change',
      );
      tester
          .widget<DialRecentHost>(find.byType(DialRecentHost))
          .onSelect(
            const DialRecentCall(
              id: 'synthetic-history',
              phone: '+81334451111',
              startedAtMillis: 1,
              source: DialRecentSource.app,
              countryIso: 'JP',
              callerLanguage: 'en',
              peerLanguage: 'en',
            ),
          );
      await tester.pumpAndSettle();
      expect(setup.snapshot.caller, 'en');
      expect(setup.snapshot.peer, 'ja');
      expect(find.textContaining('日语 对方'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ordinary unlock notice expires and cannot reappear $platform',
      (tester) async {
        final setup = TranslationSetupController()
          ..enable(false)
          ..directory(directory);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...grantedDialPermissionOverrides(),
              translationSetupProvider.overrideWith((_) => setup),
              translationDirectoryProvider.overrideWith((_) async => directory),
              translationAccessProvider.overrideWith(
                (_) => const TranslationAccess(countryIso: 'US', forced: false),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: TranslationDialerRoute(systemDialer: _NoCall()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final page = tester.widget<DialerPage>(find.byType(DialerPage));
        for (final digit in '20142014*#'.split('')) {
          page.onDigit(digit);
        }
        page.onDial();
        await tester.pumpAndSettle();
        expect(find.text('已进入开发者模式'), findsOneWidget);
        expect(find.byKey(const Key('dial-message')), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('已进入开发者模式'), findsNothing);
        setup.enable(true);
        await tester.pumpAndSettle();
        expect(find.text('已进入开发者模式'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'external JP number resets peer even in same country $platform',
      (tester) async {
        final setup = TranslationSetupController()
          ..directory(directory)
          ..country('JP', syncPeer: false)
          ..language('en', caller: false);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [translationSetupProvider.overrideWith((_) => setup)],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const TranslationDialerRoute(
                preview: true,
                number: '+81334451111',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(setup.snapshot.country, 'JP');
        expect(setup.snapshot.peer, 'ja');
        expect(find.textContaining('日语 对方'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('translation pricing is visible only while enabled $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final setup = TranslationSetupController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [translationSetupProvider.overrideWith((_) => setup)],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const TranslationDialerRoute(preview: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('translation-dial-pricing')), findsOneWidget);
      expect(
        find.text('积分按接通时的模型价格计算 · 未接通不扣', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('本次通话账单'), findsNothing);
      expect(tester.takeException(), isNull);
      setup.enable(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('translation-dial-pricing')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _NoCall implements SystemDialer {
  @override
  Future<SystemDialResult> open(String number) async =>
      throw StateError('Unexpected call');
}
