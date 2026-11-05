import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_route.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform named close only returns current history',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        try {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(const ShellPreviewPage());
          await tester.pumpUntilUiSettled();
          await tester.tap(find.byKey(const ValueKey('tab-2')));
          await tester.pumpUntilUiSettled();
          final card = find.byKey(const ValueKey('call:translation'));
          await tester.scrollUntilVisible(card, 200);
          await tester.pumpUntilUiSettled();
          await tester.tap(card);
          await tester.pumpUntilUiSettled();
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(TranslationHistoryPage)),
            ).scale(14),
            28,
          );
          final close = tester
              .widget<IconButton>(
                find.byKey(const ValueKey('close-translation')),
              )
              .onPressed!;
          final nodes = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            nodes.add(node);
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          final data = nodes
              .singleWhere((n) => n.label == '关闭翻译记录')
              .getSemanticsData();
          expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(nodes.where((n) => n.label == '×'), isEmpty);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('close-translation')))
                .shortestSide,
            greaterThanOrEqualTo(48),
          );
          close();
          close();
          await tester.pumpUntilUiSettled();
          expect(
            find.byType(TranslationHistoryRoute, skipOffstage: false),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('tab-2')), findsOneWidget);
          close();
          await tester.pumpUntilUiSettled();
          expect(find.byKey(const ValueKey('tab-2')), findsOneWidget);
          await tester.scrollUntilVisible(card, 200);
          await tester.pumpUntilUiSettled();
          await tester.tap(card);
          await tester.pumpUntilUiSettled();
          expect(find.byType(TranslationHistoryPage), findsOneWidget);
          close(); // Disposed old detail must not close the newly opened record.
          await tester.pumpUntilUiSettled();
          expect(find.byType(TranslationHistoryPage), findsOneWidget);
          await tester.tap(find.byTooltip('关闭翻译记录'));
          await tester.pumpUntilUiSettled();
          expect(find.byKey(const ValueKey('tab-2')), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpUntilUiSettled();
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
