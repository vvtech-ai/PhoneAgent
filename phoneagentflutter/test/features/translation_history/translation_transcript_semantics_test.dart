import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform captions readable once and physically selectable', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        Future<void> show(String primary) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: TranslationHistoryPage(
                  state: TranslationHistoryState(
                    content: TranslationHistoryContent(
                      '合成翻译记录',
                      '+12025550101',
                      '10月9日 10:00',
                      '00:12',
                      [
                        TranslationRow(true, primary, '这是合成字幕'),
                        const TranslationRow(false, '只有主文', ''),
                      ],
                      false,
                    ),
                  ),
                  onClose: () {},
                  onRetry: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        }

        List<SemanticsNode> nodes() {
          final result = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            result.add(node);
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
          return result;
        }

        const primary = 'Primary words for selection';
        await show(primary);
        for (final label in [primary, '这是合成字幕', '只有主文']) {
          expect(nodes().where((node) => node.label == label), hasLength(1));
        }
        final text = find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == primary,
        );
        await tester.longPressAt(
          tester.getTopLeft(text) + const Offset(20, 12),
        );
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(
          find.descendant(of: text, matching: find.byType(EditableText)),
        );
        expect(editable.controller.selection.isValid, true);
        expect(editable.controller.selection.isCollapsed, false);
        await show('Updated caption');
        expect(nodes().where((node) => node.label == primary), isEmpty);
        expect(
          nodes().where((node) => node.label == 'Updated caption'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    });
  }
}
