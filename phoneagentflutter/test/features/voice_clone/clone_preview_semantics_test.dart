import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_candidate_step.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform named preview action is unique and gated', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        var calls = 0;
        Future<void> show(CloneEnrollmentState state) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CloneCandidateStep(
                    state: state,
                    onSave: (_) {},
                    onPreview: () => calls++,
                    onConfirm: () {},
                    onRerecord: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        SemanticsNode named(String label) {
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          var buttons = 0;
          void visit(SemanticsNode value) {
            if (value.hasFlag(SemanticsFlag.isButton)) {
              buttons++;
            }
            value.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(node);
          expect(buttons, 1);
          return node;
        }

        void activate(SemanticsNode node) => tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .performAction(node.id, SemanticsAction.tap);
        await show(const CloneEnrollmentState());
        final start = named('开始试听');
        expect(start.getSemanticsData().hasAction(SemanticsAction.tap), true);
        activate(start);
        await tester.pump();
        expect(calls, 1);
        await tester.tap(find.byKey(const Key('clone-preview')));
        await tester.pump();
        expect(calls, 2);
        await show(const CloneEnrollmentState(playing: true));
        expect(find.bySemanticsLabel('开始试听'), findsNothing);
        activate(named('停止试听'));
        await tester.pump();
        expect(calls, 3);
        for (final loading in [false, true]) {
          await show(CloneEnrollmentState(busy: true, previewLoading: loading));
          final node = named(loading ? '正在读取试听' : '开始试听');
          expect(node.getSemanticsData().hasAction(SemanticsAction.tap), false);
          activate(node);
          await tester.tap(find.byKey(const Key('clone-preview')));
          await tester.pump();
          expect(calls, 3);
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        handle.dispose();
      }
    });
  }
}
