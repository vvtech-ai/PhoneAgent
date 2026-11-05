import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/native_ui_reference/flutter_language_reference.dart' as fixture;

void main() {
  testWidgets(
    'isolated language fixture returns, reopens selection and cancels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        fixture.main();
        await tester.pumpAndSettle();
        expect(find.text('我的语言'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('language-ja')));
        await tester.pumpAndSettle();
        expect(find.text('合成语种已返回：ja'), findsOneWidget);
        await tester.tap(find.text('重新选择语言'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.bySemanticsLabel('日语，日本語（日本）')),
          matchesSemantics(
            label: '日语，日本語（日本）',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('合成语种已返回：ja'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
