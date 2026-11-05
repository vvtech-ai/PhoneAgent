import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'dart:async';
import 'package:phone_agent/core/design/native_model_refresh_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';

void main() {
  Future<TranslationSetupController> open(
    WidgetTester tester, {
    bool preview = true,
    TargetPlatform platform = TargetPlatform.android,
    StateProvider<TranslationAccess>? accessState,
    Future<Map<String, TranslationModelSample>> Function()? result,
  }) async {
    final setup = TranslationSetupController();
    addTearDown(setup.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationDirectoryProvider.overrideWith(
            (ref) async => syntheticTranslationDirectory,
          ),
          translationAccessProvider.overrideWith(
            (ref) => accessState == null
                ? const TranslationAccess(countryIso: 'US', forced: false)
                : ref.watch(accessState),
          ),
          translationBillingProvider.overrideWith((_) async => {}),
          translationModelQualityProvider('DEFAULT').overrideWith((_) {
            if (result == null) throw StateError('Preview must not query');
            return result();
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showTranslationModelSheet(context, setup, preview: preview),
                child: const Text('打开模型'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开模型'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return setup;
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('shared toast after overseas change only $platform', (
      tester,
    ) async {
      await open(tester, platform: platform);
      await tester.tap(find.text('GPT Live Translate'));
      await tester.pumpAndSettle();
      expect(find.text('选择实时翻译模型'), findsNothing);
      expect(find.text('翻译通话模型已切换为 GPT Live Translate'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(find.text('翻译通话模型已切换为 GPT Live Translate'), findsNothing);
      await tester.tap(find.text('打开模型'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT Live Translate'));
      await tester.pumpAndSettle();
      expect(find.text('翻译通话模型已切换为 GPT Live Translate'), findsNothing);
      await tester.tap(find.text('打开模型'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.textContaining('翻译通话模型已切换为'), findsNothing);
    });

    testWidgets(
      'covered old model selection cannot close another page on $platform',
      (tester) async {
        final setup = await open(tester, platform: platform);
        final select = tester
            .widget<NativeTranslationModelOption>(
              find.byKey(const ValueKey('translation-model-OPENAI')),
            )
            .onSelect!;
        final context = tester.element(find.byType(TranslationModelSheet));
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('covered')),
          ),
        );
        await tester.pumpAndSettle();
        select();
        await tester.pumpAndSettle();
        expect(find.text('covered'), findsOneWidget);
        expect(setup.snapshot.provider, 'GEMINI');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'old model actions recheck live region before rebuild on $platform',
      (tester) async {
        final access = StateProvider<TranslationAccess>(
          (_) => const TranslationAccess(countryIso: 'US', forced: false),
        );
        var queries = 0;
        final setup = await open(
          tester,
          platform: platform,
          preview: false,
          accessState: access,
          result: () async {
            queries++;
            return {'OPENAI': TranslationModelSample.reachable(100)};
          },
        );
        await tester.pumpAndSettle();
        final select = tester
            .widget<NativeTranslationModelOption>(
              find.byKey(const ValueKey('translation-model-OPENAI')),
            )
            .onSelect!;
        final refresh = tester
            .widget<NativeModelRefreshButton>(
              find.byKey(const ValueKey('translation-model-refresh')),
            )
            .onRefresh!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TranslationModelSheet)),
        );
        container.read(access.notifier).state = const TranslationAccess(
          countryIso: 'CN',
          forced: false,
        );
        select();
        refresh();
        await tester.pumpAndSettle();
        expect(find.byType(TranslationModelSheet), findsOneWidget);
        expect(setup.snapshot.provider, 'GEMINI');
        expect(queries, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disposed model selection and refresh are inert on $platform', (
      tester,
    ) async {
      final setup = await open(tester, platform: platform);
      final select = tester
          .widget<NativeTranslationModelOption>(
            find.byKey(const ValueKey('translation-model-OPENAI')),
          )
          .onSelect!;
      final refresh = tester
          .widget<NativeModelRefreshButton>(
            find.byKey(const ValueKey('translation-model-refresh')),
          )
          .onRefresh!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开模型'));
      await tester.pumpAndSettle();
      refresh();
      select();
      await tester.pumpAndSettle();
      expect(find.byType(TranslationModelSheet), findsOneWidget);
      expect(setup.snapshot.provider, 'GEMINI');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selection persists and dismisses; close and reopen retain choice',
    (tester) async {
      final setup = await open(tester);
      await tester.tap(find.text('GPT Live Translate'));
      await tester.pumpAndSettle();
      expect(setup.snapshot.provider, 'OPENAI');
      expect(find.text('选择实时翻译模型'), findsNothing);
      await tester.tap(find.text('打开模型'));
      await tester.pumpAndSettle();
      final row = tester.widget<NativeTranslationModelOption>(
        find.byKey(const ValueKey('translation-model-OPENAI')),
      );
      expect(row.selected, isTrue);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(setup.snapshot.provider, 'OPENAI');
      expect(find.text('打开模型'), findsOneWidget);
    },
  );
  testWidgets('back and backdrop cancel preserve base and allow reopen', (
    tester,
  ) async {
    final setup = await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(setup.snapshot.provider, 'GEMINI');
    await tester.tap(find.text('打开模型'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('选择实时翻译模型'), findsNothing);
    expect(setup.snapshot.provider, 'GEMINI');
  });
  testWidgets('mock refresh shows recoverable failure without real provider', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('140ms'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新模型状态'));
    await tester.pump();
    expect(find.text('不可用'), findsNWidgets(3));
    await tester.tap(find.byTooltip('刷新模型状态'));
    await tester.pump();
    expect(find.textContaining('140ms'), findsOneWidget);
  });
  testWidgets(
    'real refresh single-flight, errors visible and late close safe',
    (tester) async {
      final pending = <Completer<Map<String, TranslationModelSample>>>[];
      await open(
        tester,
        preview: false,
        result: () {
          final gate = Completer<Map<String, TranslationModelSample>>();
          pending.add(gate);
          return gate.future;
        },
      );
      expect(pending, hasLength(1));
      expect(
        tester
            .widget<NativeModelRefreshButton>(
              find.byKey(const ValueKey('translation-model-refresh')),
            )
            .onRefresh,
        isNull,
      );
      pending.single.complete({
        'OPENAI': const TranslationModelSample.unavailable(),
        'GEMINI': TranslationModelSample.reachable(250),
      });
      await tester.pumpAndSettle();
      expect(find.text('不可用'), findsNWidgets(3));
      await tester.tap(find.byTooltip('刷新模型状态'));
      await tester.pump();
      await tester.pump();
      expect(pending, hasLength(2));
      expect(
        tester
            .widget<NativeModelRefreshButton>(
              find.byKey(const ValueKey('translation-model-refresh')),
            )
            .onRefresh,
        isNull,
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      pending.last.complete({});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('选择实时翻译模型'), findsNothing);
    },
  );
  testWidgets('latency semantics distinguish pending, failure and recovery', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final pending = Completer<Map<String, TranslationModelSample>>();
    await open(tester, preview: false, result: () => pending.future);
    expect(find.bySemanticsLabel(RegExp('模型延迟暂无数据')), findsNWidgets(2));
    expect(find.text('不可用'), findsNWidgets(2));
    pending.complete({
      'OPENAI': const TranslationModelSample.unavailable(),
      'GEMINI': TranslationModelSample.reachable(250),
    });
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('模型不可用')), findsNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('模型延迟一般，250毫秒')), findsOneWidget);
    expect(find.text('250ms'), findsOneWidget);
    expect(find.textContaining('不代表模型已开通或通话已就绪'), findsNothing);
    semantics.dispose();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('model sheet stays interactive on $width short screen', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Gemini Live'));
      await tester.tap(find.text('Gemini Live'));
      await tester.pumpAndSettle();
      expect(find.text('选择实时翻译模型'), findsNothing);
    });
  }
}
