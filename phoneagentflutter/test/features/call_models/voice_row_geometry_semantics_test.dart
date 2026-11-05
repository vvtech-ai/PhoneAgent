import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform compact voice row independent actions large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          var selected = 0, previewed = 0;
          Future<void> show({
            bool current = false,
            bool previewEnabled = true,
          }) async {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 568),
                    textScaler: TextScaler.linear(large ? 2 : 1),
                  ),
                  child: Scaffold(
                    body: Column(
                      children: [
                        NativeVoiceSelectionRow(
                          voice: const CallVoice(
                            'Andre',
                            'Andre',
                            '清朗男声',
                            true,
                          ),
                          selected: current,
                          enabled: true,
                          onSelect: () => selected++,
                          showPreview: true,
                          onPreview: previewEnabled ? () => previewed++ : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          try {
            await show();
            final row = find.byType(NativeVoiceSelectionRow);
            expect(tester.getSize(row).height, large ? greaterThan(67) : 67);
            final preview = find.bySemanticsLabel('试听Andre');
            expect(tester.getSize(preview), const Size(48, 48));
            final nodes = <SemanticsNode>[];
            void collect(SemanticsNode node) {
              nodes.add(node);
              node.visitChildren((child) {
                collect(child);
                return true;
              });
            }

            collect(
              tester
                  .binding
                  .renderViews
                  .single
                  .owner!
                  .semanticsOwner!
                  .rootSemanticsNode!,
            );
            final selection = nodes.singleWhere(
              (node) =>
                  node.label.contains('Andre') &&
                  !node.label.contains('试听') &&
                  node.hasFlag(SemanticsFlag.isButton),
            );
            final previewNode = tester.getSemantics(preview);
            for (
              var parent = previewNode.parent;
              parent != null;
              parent = parent.parent
            ) {
              expect(parent, isNot(same(selection)));
            }
            await tester.tap(preview);
            expect([selected, previewed], [0, 1]);
            final center = tester.getCenter(preview);
            for (final offset in [
              const Offset(-23, 0),
              const Offset(23, 0),
              const Offset(0, -23),
              const Offset(0, 23),
            ]) {
              await tester.tapAt(center + offset);
            }
            expect([selected, previewed], [0, 5]);
            await tester.tap(
              find.byKey(const ValueKey('voice-selection:Andre')),
            );
            expect([selected, previewed], [1, 5]);
            await show(current: true);
            final currentNode = tester.getSemantics(
              find.bySemanticsLabel('Andre，清朗男声'),
            );
            expect(currentNode.hasFlag(SemanticsFlag.isSelected), isTrue);
            expect(currentNode.hasFlag(SemanticsFlag.isEnabled), isFalse);
            expect(
              currentNode.getSemanticsData().hasAction(SemanticsAction.tap),
              isFalse,
            );
            await tester.tap(
              find.byKey(const ValueKey('voice-selection:Andre')),
            );
            expect([selected, previewed], [1, 5]);
            await tester.tap(preview);
            expect([selected, previewed], [1, 6]);
            await show(previewEnabled: false);
            await tester.tap(preview);
            expect([selected, previewed], [1, 6]);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
