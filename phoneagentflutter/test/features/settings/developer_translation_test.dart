import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_location_host.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_model_selection_providers.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import '../../support/developer_tools_fixture.dart';

void main() {
  testWidgets(
    'simulation hides device location shortcut in called-country picker',
    (tester) async {
      final f = await openDeveloperTools(tester);
      f.container.read(translationSetupProvider.notifier).simulateCountry('JP');
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: MaterialApp(
            home: Scaffold(
              body: DialLocationHost(
                onSelected: (_) =>
                    fail('hidden location cannot select called country'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dial-location-select')), findsNothing);
      expect(find.byKey(const Key('dial-location-request')), findsNothing);
      expect(f.location.requests, 0);
    },
  );
  testWidgets('locked route loads no preferences', (tester) async {
    final fixture = await openDeveloperTools(tester, unlocked: false);
    expect(find.text('开发者入口尚未解锁'), findsOneWidget);
    expect(fixture.store.reads, 0);
    expect(find.text('模拟国家定位'), findsNothing);
  });
  testWidgets(
    'country search persists override, switches model and leaves GPS/called country untouched',
    (tester) async {
      final f = await openDeveloperTools(tester);
      final original = f.store.value.translationCountry;
      expect(f.container.read(translationAccessProvider).countryIso, 'CN');
      await tester.tap(find.text('选择 ›'));
      await tester.pumpAndSettle();
      expect(find.text('主叫所在国家'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('developer-country-search')),
        'jp',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('developer-country-CN')), findsNothing);
      await tester.tap(find.byKey(const Key('developer-country-JP')));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, 'JP');
      expect(f.store.value.translationCountry, original);
      expect(f.location.cached!.countryIso, 'CN');
      expect(f.location.requests, 0);
      expect(f.container.read(translationAccessProvider).countryIso, 'JP');
      expect(
        f.container.read(selectedTranslationModelProvider)?.transport,
        'BACKEND_WEBRTC',
      );
      expect(
        TranslationPreferenceCodec.decode(
          TranslationPreferenceCodec.encode(f.store.value),
        ).simulatedCountryIso,
        'JP',
      );
      await tester.tap(find.text('模拟国家定位'));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, '');
      expect(f.location.requests, 1);
      expect(
        f.container
            .read(effectiveTranslationLocationProvider)
            .trusted!
            .countryIso,
        'US',
      );
    },
  );
  testWidgets(
    'back does not select, automatic clears, failed save remains retryable',
    (tester) async {
      final f = await openDeveloperTools(tester);
      await tester.tap(find.text('选择 ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回').last);
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, '');
      f.store.writeFails = true;
      await tester.tap(find.text('模拟国家定位'));
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未保存'), findsOneWidget);
      expect(find.text('模拟定位国家设置失败'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      f.store.writeFails = false;
      await tester.tap(find.text('重试保存'));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, 'CN');
      f.store.writeFails = true;
      await tester.tap(find.text('选择 ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自动定位'));
      await tester.pumpAndSettle();
      expect(find.text('恢复自动定位失败'), findsOneWidget);
      expect(f.store.value.simulatedCountryIso, 'CN');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      f.store.writeFails = false;
      await tester.tap(find.text('重试保存'));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, '');
      expect(tester.takeException(), isNull);
    },
  );
}
