import 'dart:ui' show SemanticsAction, SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'setting choice named selection and single action $platform $scale',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            var selected = true, enabled = true, actions = 0;
            late StateSetter change;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: Scaffold(
                        body: NativeSettingChoice(
                          label: 'GPT Live Translate',
                          selected: selected,
                          onTap: enabled ? () => actions++ : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
            final named = find.bySemanticsLabel('GPT Live Translate');
            expect(named, findsOneWidget);
            void verify({required bool selected, required bool enabled}) {
              final data = tester.getSemantics(named).getSemanticsData();
              expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(data.hasFlag(SemanticsFlag.hasSelectedState), isTrue);
              expect(data.hasFlag(SemanticsFlag.isSelected), selected);
              expect(data.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
              expect(data.hasFlag(SemanticsFlag.isEnabled), enabled);
              expect(data.hasAction(SemanticsAction.tap), enabled);
            }

            verify(selected: true, enabled: true);
            expect(
              tester.getSize(find.byType(OutlinedButton)).height,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.byType(OutlinedButton));
            expect(actions, 1);
            tester.binding.renderViews.single.owner!.semanticsOwner!
                .performAction(
                  tester.getSemantics(named).id,
                  SemanticsAction.tap,
                );
            await tester.pump();
            expect(actions, 2);
            change(() => selected = false);
            await tester.pump();
            verify(selected: false, enabled: true);
            change(() {
              enabled = false;
              selected = true;
            });
            await tester.pump();
            verify(selected: true, enabled: false);
            expect(actions, 2);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
