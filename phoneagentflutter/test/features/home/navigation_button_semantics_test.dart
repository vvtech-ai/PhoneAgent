import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 336.0, 338.0, 393.0]) {
      final compact = width < 338;
      testWidgets('$platform navigation named buttons width=$width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = compact
            ? const Size(320, 568)
            : const Size(393, 820);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        var selected = 0, dials = 0;
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: StatefulBuilder(
                  builder: (context, rebuild) => FloatingNavigation(
                    selected: selected,
                    onSelected: (index) {
                      selections.add(index);
                      rebuild(() => selected = index);
                    },
                    onDial: () => dials++,
                  ),
                ),
              ),
            ),
          ),
        );
        List<SemanticsNode> nodes() {
          final all = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            all.add(node);
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
          return all;
        }

        const labels = ['首页', '联系人', '任务', '设置'];
        for (var index = 0; index < labels.length; index++) {
          for (var item = 0; item < labels.length; item++) {
            final data = nodes()
                .singleWhere((n) => n.label == labels[item])
                .getSemanticsData();
            expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
            expect(data.hasFlag(SemanticsFlag.isImage), isFalse);
            expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
            expect(data.hasFlag(SemanticsFlag.isSelected), item == selected);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            final rect = tester.getRect(find.byKey(ValueKey('tab-$item')));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.bySemanticsLabel(labels[index]));
          await tester.pump();
          expect(selected, index);
        }
        expect(selections, [0, 1, 2, 3]);
        final dial = nodes()
            .singleWhere((n) => n.label == '打开拨号盘')
            .getSemanticsData();
        expect(dial.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(dial.hasAction(SemanticsAction.tap), isTrue);
        expect(
          tester.getSize(find.byKey(const ValueKey('assistantFab'))),
          const Size(60, 60),
        );
        await tester.tap(find.bySemanticsLabel('打开拨号盘'));
        expect(dials, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
