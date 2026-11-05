import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_country_page.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';
import '../../../tool/previews/shell_translation_preview.dart';
import '../../support/translation_directory_fixture.dart';

Map<String, Object?> _options({String subtitle = ''}) {
  final dto = translationOptionsFixture();
  for (final row in dto['countries'] as List) {
    if ((row as Map)['countryCode'] == 'US') {
      row['phoneRegex'] = r'^202[0-9]{7}$';
    }
  }
  for (final row in dto['models'] as List) {
    (row as Map).addAll(<String, Object>{
      'firstMinutePoints': 150,
      'sixSecondPoints': 15,
      'blockDurationSeconds': 6,
      'firstPeriodDurationMs': 60000,
      'appSubtitle': subtitle,
      'recommended': true,
    });
  }
  return dto;
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  TargetPlatform platform, {
  Future<TranslationDirectory> Function()? directory,
  double scale = 1,
  String subtitle = '',
}) async {
  final ports = ShellTranslationPreviewPorts(
    originalAudio: () => const OriginalAudioSettings(),
  );
  ports.preferences.value = const TranslationPreferences(
    prompt: false,
    translationCountry: 'US',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...ports.overrides.skip(1),
        translationDirectoryProvider.overrideWith(
          (_) =>
              directory?.call() ??
              Future.value(
                ApiTranslationDirectory.decode(_options(subtitle: subtitle)),
              ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const TranslationDialerRoute(
          number: '123456789',
          countryIso: 'US',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(TranslationDialerRoute)),
  );
}

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'pricing sits below dial with gold stars at large scale $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = await _open(tester, platform, scale: 2);
        final pricing = find.byKey(const Key('translation-dial-pricing'));
        expect(
          tester.getTopLeft(pricing).dy,
          greaterThan(
            tester.getBottomLeft(find.byKey(const Key('dial-call'))).dy,
          ),
        );
        final rich = tester.widget<RichText>(pricing);
        final root = rich.text as TextSpan;
        expect(root.style?.color, const Color(0xFF9297A1));
        expect(root.style?.fontSize, 10);
        expect(root.style?.height, 1.4);
        final stars = root.children!
            .whereType<TextSpan>()
            .where((span) => span.text == '✦')
            .toList();
        expect(stars, hasLength(2));
        expect(
          stars.every((span) => span.style?.color == const Color(0xFFFFC400)),
          isTrue,
        );
        expect(rich.text.toPlainText(), contains('✦150'));
        expect(tester.getBottomLeft(pricing).dy, lessThanOrEqualTo(568));
        expect(tester.takeException(), isNull);
        container.read(translationSetupProvider.notifier).enable(false);
        await tester.pumpAndSettle();
        expect(pricing, findsNothing);
        expect(find.text('本次通话账单'), findsNothing);
      },
    );

    testWidgets(
      'manual equal languages survive access recomputation and warn before format $platform',
      (tester) async {
        final container = await _open(tester, platform);
        final setup = container.read(translationSetupProvider.notifier);
        final page = tester.widget<DialerPage>(find.byType(DialerPage));
        final context = tester.element(find.byType(DialerPage));
        unawaited(showTranslationPresets(context, setup, setup.enable));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('translation-peer')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('language-zh')));
        await tester.pumpAndSettle();
        expect(setup.snapshot.caller, 'zh');
        expect(setup.snapshot.peer, 'zh');
        await tester.tap(find.byKey(const Key('translation-presets-close')));
        await tester.pumpAndSettle();
        page.onDial();
        await tester.pumpAndSettle();
        expect(find.text('请选择不同的我方和对方语种'), findsOneWidget);
        expect(find.text('号码格式提醒'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'country entry refreshes once with retained list and manual language $platform',
      (tester) async {
        var reads = 0;
        final fresh = Completer<TranslationDirectory>();
        final container = await _open(
          tester,
          platform,
          directory: () async {
            return ++reads == 1
                ? ApiTranslationDirectory.decode(_options())
                : fresh.future;
          },
        );
        final setup = container.read(translationSetupProvider.notifier);
        setup.language('zh', caller: false);
        await tester.pumpAndSettle();
        tester.widget<DialerPage>(find.byType(DialerPage)).onCountry();
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(
          tester
              .widget<DialCountryPage>(find.byType(DialCountryPage))
              .countries,
          hasLength(4),
        );
        final dto = _options();
        (dto['countries'] as List).add({
          'countryCode': 'GB',
          'dialCode': '+44',
          'nameZh': '英国',
          'defaultLanguageCode': 'en',
          'availableModelIds': ['GEMINI'],
        });
        fresh.complete(ApiTranslationDirectory.decode(dto));
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(
          tester
              .widget<DialCountryPage>(find.byType(DialCountryPage))
              .countries,
          hasLength(5),
        );
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(setup.snapshot.peer, 'zh');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'unavailable regional model explains why without recommendation $platform',
      (tester) async {
        final container = await _open(tester, platform);
        final setup = container.read(translationSetupProvider.notifier);
        unawaited(
          showTranslationModelSheet(
            tester.element(find.byType(DialerPage)),
            setup,
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(
          const ValueKey('translation-model-QWEN_OMNI_PLUS'),
        );
        final option = tester.widget<NativeTranslationModelOption>(row);
        expect(option.onSelect, isNull);
        expect(
          find.descendant(of: row, matching: find.text('当前地区不可用')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('推荐')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'nonempty model subtitle still explains unavailable region $platform',
      (tester) async {
        final container = await _open(
          tester,
          platform,
          subtitle: List.filled(12, '服务器原说明').join(),
        );
        unawaited(
          showTranslationModelSheet(
            tester.element(find.byType(DialerPage)),
            container.read(translationSetupProvider.notifier),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(
          const ValueKey('translation-model-QWEN_OMNI_PLUS'),
        );
        expect(
          tester.widget<NativeTranslationModelOption>(row).subtitle,
          '当前地区不可用',
        );
        expect(
          find.descendant(of: row, matching: find.text('当前地区不可用')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('推荐')),
          findsNothing,
        );
      },
    );
  }
}
