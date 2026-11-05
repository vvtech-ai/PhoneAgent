import 'package:phone_agent/core/widgets/route_provider_scope.dart';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_settings_route.dart';
import 'package:phone_agent/features/translation/presentation/widgets/domestic_translation_model_sheet.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_access_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';

void main() {
  Future<void> press(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 8,
      );
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TranslationAccessPreviewPage()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    final native = find.byTooltip('返回');
    await press(
      tester,
      native.evaluate().isNotEmpty ? native.last : find.byTooltip('Back').last,
    );
  }

  Future<void> model(WidgetTester tester) =>
      press(tester, find.byKey(const ValueKey('translation-model-open')));

  testWidgets(
    'CN international prefix uses domestic model sheet and never starts an overseas call',
    (tester) async {
      await open(tester);
      await press(tester, find.text('进入共享翻译拨号页'));
      expect(find.text('海外模型与服务区域'), findsNothing);
      await model(tester);
      final sheet = find.byType(DomesticTranslationModelSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Qwen3.5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('translation-model-OPENAI')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('translation-model-GEMINI')),
        findsNothing,
      );
      expect(find.text('翻译体验更稳定，适合大多数通话'), findsOneWidget);
      expect(find.text('即将支持 · 适用于海外'), findsNWidgets(2));
      await press(tester, find.byKey(const ValueKey('domestic-model-DOUBAO')));
      expect(sheet, findsNothing);
      expect(find.bySemanticsLabel('翻译模型：Doubao'), findsOneWidget);
      await press(tester, find.byKey(const Key('dial-call')));
      expect(find.text('当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用'), findsOneWidget);
      expect(find.textContaining('国内 SIP 翻译暂不迁移'), findsNothing);
    },
  );
  testWidgets(
    'developer country simulation reaches dialer without changing trusted CN',
    (tester) async {
      await open(tester);
      await press(tester, find.text('进入共享开发者设置'));
      await press(tester, find.text('选择 ›'));
      await press(tester, find.byKey(const Key('developer-country-JP')));
      final container = ProviderScope.containerOf(
        tester.element(find.text('开发者功能')),
      );
      expect(
        container.read(translationLocationProvider).trusted?.countryIso,
        'CN',
      );
      await back(tester);
      await press(tester, find.text('进入共享翻译拨号页'));
      await model(tester);
      expect(
        find.byKey(const ValueKey('translation-model-OPENAI')),
        findsOneWidget,
      );
      await press(tester, find.text('GPT Live Translate'));
      expect(find.bySemanticsLabel('翻译模型：GPT Live Translate'), findsOneWidget);
      await press(tester, find.byKey(const Key('dial-call')));
      expect(find.text('当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用'), findsOneWidget);
    },
  );
  testWidgets(
    'unknown location opens country simulation picker and can choose a bound country',
    (tester) async {
      await open(tester);
      await press(tester, find.text('模拟 未知'));
      await press(tester, find.text('进入共享开发者设置'));
      await press(tester, find.text('模拟国家定位'));
      expect(find.text('主叫所在国家'), findsOneWidget);
      await press(tester, find.byKey(const Key('developer-country-US')));
      await back(tester);
      await press(tester, find.text('进入共享翻译拨号页'));
      await model(tester);
      expect(
        tester
            .widget<NativeTranslationModelOption>(
              find.byKey(const ValueKey('translation-model-OPENAI')),
            )
            .onSelect,
        isNotNull,
      );
    },
  );
  testWidgets(
    'US selection uses directory pricing despite legacy billing failure',
    (tester) async {
      await open(tester);
      await press(tester, find.text('模拟 US'));
      await press(tester, find.text('倍率查询失败'));
      await press(tester, find.text('进入共享翻译拨号页'));
      // Mount retained configuration directly; no production entry is added.
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
      await press(
        tester,
        find.byKey(const ValueKey('translation-setting-region-JP')),
      );
      await back(tester);
      await model(tester);
      expect(find.text('计费倍率暂未获取，不显示估算值'), findsNothing);
      await press(tester, find.text('GPT Live Translate'));
      expect(find.bySemanticsLabel('翻译模型：GPT Live Translate'), findsOneWidget);
    },
  );
  testWidgets('directory dependency reload hides previous model pricing', (
    tester,
  ) async {
    final first = Completer<TranslationDirectory>(),
        second = Completer<TranslationDirectory>();
    final selected = StateProvider<Future<TranslationDirectory>>(
      (_) => first.future,
    );
    TranslationDirectory priced(double rate) {
      final dto = translationOptionsFixture();
      ((dto['models'] as List)[2] as Map)['billingMultiplier'] = rate;
      return ApiTranslationDirectory.decode(dto);
    }

    final container = ProviderContainer(
      overrides: [
        translationAccessProvider.overrideWithValue(
          const TranslationAccess(countryIso: 'US', forced: false),
        ),
        translationModelQualityProvider(
          'DEFAULT',
        ).overrideWith((_) async => {}),
        translationDirectoryProvider.overrideWith((ref) => ref.watch(selected)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TranslationModelSheet(selected: 'GEMINI', region: 'DEFAULT'),
          ),
        ),
      ),
    );
    first.complete(priced(1.2));
    await tester.pumpAndSettle();
    expect(find.text('×1.2'), findsOneWidget);
    container.read(selected.notifier).state = second.future;
    await tester.pump();
    await tester.pump();
    expect(find.text('×1.2'), findsNothing);
    expect(find.text('计费倍率读取中'), findsNothing);
    second.complete(priced(2.3));
    await tester.pumpAndSettle();
    expect(find.text('×2.3'), findsOneWidget);
  });
}
