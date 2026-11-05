import 'package:phone_agent/core/widgets/route_provider_scope.dart';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_settings_route.dart';
import 'dart:async';
import '../../support/dial_permission_overrides.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'translation_preferences_persistence_test.dart'
    show MemoryTranslationStore;
import 'translation_pages_test.dart' show RecordingDialer;

void main() {
  Future<void> host(
    WidgetTester tester,
    MemoryTranslationStore store,
    RecordingDialer dialer,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationDirectoryProvider.overrideWith((ref) async {
            final dto = translationOptionsFixture();
            (dto['languages'] as List).add(<String, Object>{
              'code': 'de',
              'displayName': '德语',
            });
            for (final model in (dto['models'] as List).cast<Map>()) {
              (model['sourceLanguageCodes'] as List).add('de');
              (model['targetLanguageCodes'] as List).add('de');
            }
            ((dto['countries'] as List)[2] as Map)['dialCode'] = '+81';
            return ApiTranslationDirectory.decode(dto);
          }),
          ...grantedDialPermissionOverrides(),
          translationAccessProvider.overrideWithValue(
            const TranslationAccess(countryIso: 'US', forced: false),
          ),
          systemDialRecentSourceProvider.overrideWithValue(
            const UnavailableDialRecentSource(DialRecentAccess.unsupported),
          ),
          translationPreferenceStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TranslationDialerRoute(systemDialer: dialer),
                  ),
                ),
                child: const Text('进入配置'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入配置'));
    await tester.pumpAndSettle();
  }

  // Test-only route: production no longer exposes an overseas settings entry.
  Future<void> openSettings(WidgetTester tester) async {
    final context = tester.element(find.byType(TranslationDialerRoute));
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RouteProviderScope(
          container: container,
          child: TranslationSettingsRoute(
            controller: container.read(translationSetupProvider.notifier),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'stored preferences restore and closing route does not abort saving',
    (tester) async {
      final store = MemoryTranslationStore()
        ..value = const TranslationPreferences(
          caller: 'de',
          peer: 'fr',
          translationCountry: 'JP',
          normalCountry: 'SG',
        )
        ..writeGate = Completer<void>();
      final dialer = RecordingDialer();
      await host(tester, store, dialer);
      expect(find.textContaining('我方 德语'), findsOneWidget);
      expect(find.textContaining('法语 对方'), findsOneWidget);
      expect(find.textContaining('+81'), findsWidgets);
      await openSettings(tester);
      await press(tester, find.text('GPT Live Translate'));
      await press(
        tester,
        find.byKey(const ValueKey('translation-setting-region-US')),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('进入配置'), findsOneWidget);
      store.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(store.value.provider, 'OPENAI');
      expect(store.value.region, 'US');
      await press(tester, find.text('进入配置'));
      expect(find.textContaining('法语 对方'), findsOneWidget);
      await openSettings(tester);
      expect(
        tester
            .widget<NativeSettingChoice>(
              find.byKey(const ValueKey('translation-setting-model-OPENAI')),
            )
            .selected,
        isTrue,
      );
      expect(store.reads, 1);
      expect(dialer.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read failure exposes retry and blocks calls/default writes', (
    tester,
  ) async {
    final store = MemoryTranslationStore()..readFails = true;
    final dialer = RecordingDialer();
    await host(tester, store, dialer);
    expect(find.text('读取翻译配置失败，请重试'), findsOneWidget);
    await press(tester, find.byKey(const Key('dial-call')));
    expect(dialer.calls, isEmpty);
    expect(store.writes, isEmpty);
    store.readFails = false;
    await press(tester, find.text('重试读取'));
    expect(find.text('读取翻译配置失败，请重试'), findsNothing);
    expect(find.textContaining('我方 中文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('model page save failure stays visible and retry keeps choice', (
    tester,
  ) async {
    final store = MemoryTranslationStore()..writeFails = true;
    final dialer = RecordingDialer();
    await host(tester, store, dialer);
    await openSettings(tester);
    await press(tester, find.text('GPT Live Translate'));
    expect(find.text('翻译配置尚未保存，请重试'), findsOneWidget);
    expect(
      tester
          .widget<NativeSettingChoice>(
            find.byKey(const ValueKey('translation-setting-model-OPENAI')),
          )
          .selected,
      isTrue,
    );
    store.writeFails = false;
    await press(tester, find.text('重试保存'));
    expect(store.value.provider, 'OPENAI');
    expect(find.text('重试保存'), findsNothing);
    expect(dialer.calls, isEmpty);
  });
}
