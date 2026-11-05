import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'translation_model_identity_test.dart' show multiModels;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/presentation/widgets/domestic_translation_model_sheet.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'support/domestic_model_sheet_fixture.dart';

void main() {
  testWidgets('directory failure is explicit and summary retry recovers', (
    tester,
  ) async {
    var fail = true;
    final repo = SheetRepository()..failLoad = true;
    await mountSheetDialer(
      tester,
      repo,
      loadDirectory: () async {
        if (fail) throw StateError('synthetic directory failure');
        return syntheticTranslationDirectory;
      },
    );
    expect(find.bySemanticsLabel('翻译模型：模型加载失败，点击重试'), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const ValueKey('translation-model-open')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('翻译模型：Qwen3.5'), findsOneWidget);
    expect(repo.reads, 0);
  });
  testWidgets('same protocol models have independent selectable IDs', (
    tester,
  ) async {
    final directory = ApiTranslationDirectory.decode(multiModels());
    final container = await mountSheetDialer(
      tester,
      SheetRepository(),
      loadDirectory: () async => directory,
    );
    container.read(translationSetupProvider.notifier).directory(directory);
    await openSheet(tester);
    final key = find.byKey(const ValueKey('domestic-model-qwen-custom-second'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pumpAndSettle();
    expect(
      container.read(translationSetupProvider).value.domesticModelId,
      'qwen-custom-second',
    );
    expect(find.bySemanticsLabel('翻译模型：第二个千问'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'directory choice persists without account setting $platform/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final repo = SheetRepository()
            ..failLoad = true
            ..failSelect = true;
          final container = await mountSheetDialer(
            tester,
            repo,
            scale: scale,
            platform: platform,
          );
          expect(find.bySemanticsLabel('翻译模型：Qwen3.5'), findsOneWidget);
          await openSheet(tester);
          expect(find.text('选择实时翻译模型'), findsOneWidget);
          expect(find.text('推荐'), findsOneWidget);
          expect(find.text('×1.1'), findsOneWidget);
          await selectDoubao(tester);
          expect(find.byType(DomesticTranslationModelSheet), findsNothing);
          expect(find.bySemanticsLabel('翻译模型：Doubao'), findsOneWidget);
          expect(
            container.read(translationSetupProvider).value.domesticModelId,
            'DOUBAO',
          );
          expect(repo.reads, 0);
          expect(repo.switches, 0);
          await openSheet(tester);
          expect(
            tester
                .widget<NativeTranslationModelOption>(
                  find.byKey(const ValueKey('domestic-model-DOUBAO')),
                )
                .selected,
            isTrue,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('拨号页号码 13800000000'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('unsupported transport shown but cannot select', (tester) async {
    await mountSheetDialer(tester, SheetRepository());
    await openSheet(tester);
    expect(
      tester
          .widget<NativeTranslationModelOption>(
            find.byKey(const ValueKey('domestic-model-OPENAI')),
          )
          .onSelect,
      isNull,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(DomesticTranslationModelSheet), findsNothing);
  });
}
