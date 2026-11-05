import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/translation/domain/translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../../support/dial_permission_overrides.dart';

final _epoch = StateProvider<int>((_) => 1);

class _Port implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

class _Store implements TranslationPreferenceStore {
  Completer<TranslationPreferences>? readGate;
  var value = const TranslationPreferences(enabled: false, prompt: false);
  @override
  Future<TranslationPreferences> read() async => readGate?.future ?? value;
  @override
  Future<void> write(TranslationPreferences next) async => value = next;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<ProviderContainer> host(
      WidgetTester tester,
      _Store store,
      _Port port, {
      bool translationEntry = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          ...grantedDialPermissionOverrides(),
          translationBillingProvider.overrideWith((_) async => const {}),
          systemDialRecentSourceProvider.overrideWithValue(
            const UnavailableDialRecentSource(DialRecentAccess.unsupported),
          ),
          loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
          systemDialerProvider.overrideWithValue(port),
          translationPreferenceStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => TranslationDialerRoute(
                      translationEntry: translationEntry,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return container;
    }

    testWidgets('$platform old login callbacks cannot edit new draft', (
      tester,
    ) async {
      final store = _Store(), port = _Port();
      final container = await host(tester, store, port);
      final oldPage = tester.widget<DialerPage>(find.byType(DialerPage));
      oldPage.onDigit('7');
      await tester.pumpAndSettle();
      expect(container.read(dialerControllerProvider).input, '7');
      container.read(_epoch.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(container.read(dialerControllerProvider).input, isEmpty);
      oldPage.onDigit('8');
      oldPage.onDelete();
      oldPage.onClear();
      oldPage.onDial();
      oldPage.onCountry();
      await tester.pumpAndSettle();
      expect(container.read(dialerControllerProvider).input, isEmpty);
      expect(port.calls, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$platform closed entry does not apply late translation intent',
      (tester) async {
        final store = _Store()..readGate = Completer<TranslationPreferences>();
        final port = _Port();
        final container = await host(
          tester,
          store,
          port,
          translationEntry: true,
        );
        tester.widget<DialerPage>(find.byType(DialerPage)).onClose();
        await tester.pump(const Duration(milliseconds: 500));
        store.readGate!.complete(store.value);
        await tester.pumpAndSettle();
        expect(container.read(translationSetupProvider).value.enabled, isFalse);
        expect(find.text('open'), findsOneWidget);
        expect(port.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform active entry applies intent after preferences load',
      (tester) async {
        final store = _Store()..readGate = Completer<TranslationPreferences>();
        final port = _Port();
        final container = await host(
          tester,
          store,
          port,
          translationEntry: true,
        );
        store.readGate!.complete(store.value);
        await tester.pumpAndSettle();
        expect(container.read(translationSetupProvider).value.enabled, isTrue);
        expect(store.value.enabled, isTrue);
        expect(port.calls, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
