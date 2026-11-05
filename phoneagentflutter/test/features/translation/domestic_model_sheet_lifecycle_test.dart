import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/presentation/widgets/domestic_translation_model_sheet.dart';
import 'support/domestic_model_sheet_fixture.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';

void main() {
  testWidgets('double opening presents one sheet', (tester) async {
    final repo = SheetRepository();
    await mountSheetDialer(tester, repo);
    final open = find.byKey(const ValueKey('translation-model-open'));
    await tester.tap(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(DomesticTranslationModelSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DomesticTranslationModelSheet), findsNothing);
  });

  for (final access in [
    const TranslationAccess(countryIso: 'US', forced: false),
    const TranslationAccess(countryIso: null, forced: false),
    const TranslationAccess(countryIso: 'CN', forced: true),
  ]) {
    testWidgets(
      'changed access blocks choice ${access.countryIso}/${access.forced}',
      (tester) async {
        final repo = SheetRepository();
        final container = await mountSheetDialer(tester, repo);
        await openSheet(tester);
        final stale = tester
            .widget<NativeTranslationModelOption>(
              find.byKey(const ValueKey('domestic-model-DOUBAO')),
            )
            .onSelect!;
        container.read(sheetAccess.notifier).state = access;
        await tester.pumpAndSettle();
        expect(find.text('当前位置或账号已变化，请关闭后重新选择模型'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('domestic-model-DOUBAO')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<NativeTranslationModelOption>(
                find.byKey(const ValueKey('domestic-model-DOUBAO')),
              )
              .onSelect,
          isNull,
        );
        stale();
        await tester.pumpAndSettle();
        expect(repo.switches, 0);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        await openSheet(tester);
        expect(find.byType(DomesticTranslationModelSheet), findsNothing);
      },
    );
  }

  testWidgets('changed account makes old callback inert', (tester) async {
    final repo = SheetRepository();
    final container = await mountSheetDialer(tester, repo);
    await openSheet(tester);
    final stale = tester
        .widget<NativeTranslationModelOption>(
          find.byKey(const ValueKey('domestic-model-DOUBAO')),
        )
        .onSelect!;
    container.read(sheetLogin.notifier).state++;
    await tester.pumpAndSettle();
    expect(find.text('当前位置或账号已变化，请关闭后重新选择模型'), findsOneWidget);
    stale();
    await tester.pumpAndSettle();
    expect(container.read(translationSetupProvider).value.domesticModelId, '');
    expect(find.byType(DomesticTranslationModelSheet), findsOneWidget);
    expect(repo.switches, 0);
  });
  testWidgets('closed sheet callback cannot pop newer route', (tester) async {
    await mountSheetDialer(tester, SheetRepository());
    await openSheet(tester);
    final stale = tester
        .widget<NativeTranslationModelOption>(
          find.byKey(const ValueKey('domestic-model-DOUBAO')),
        )
        .onSelect!;
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开其他页面'));
    await tester.pumpAndSettle();
    stale();
    await tester.pumpAndSettle();
    expect(find.text('其他页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
