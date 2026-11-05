import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_enrollment_steps.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform clone identity named editing and gates', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final submissions = <List<String>>[];
        Future<void> show({bool busy = false, String verifiedName = ''}) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CloneIdentityStep(
                    key: ValueKey(verifiedName),
                    busy: busy,
                    prefilledName: '合成身份',
                    verifiedName: verifiedName,
                    onSubmit: (name, number) => submissions.add([name, number]),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        SemanticsNode field(String label) {
          final nodes = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            if (node.hasFlag(SemanticsFlag.isTextField) &&
                node.label.contains(label)) {
              nodes.add(node);
            }
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
          expect(nodes, hasLength(1), reason: label);
          return nodes.single;
        }

        bool editable(String label) =>
            field(label).getSemanticsData().hasAction(SemanticsAction.setText);
        Future<void> edit(String label, int index, String value) async {
          await tester.tap(find.byType(TextField).at(index));
          await tester.pumpAndSettle();
          expect(field(label).hasFlag(SemanticsFlag.isFocused), true);
          expect(editable(label), true);
          tester.binding.renderViews.single.owner!.semanticsOwner!
              .performAction(field(label).id, SemanticsAction.setText, value);
          await tester.pumpAndSettle();
          expect(field(label).value, value);
        }

        await show();
        expect(field('姓名').value, '合成身份');
        await edit('姓名', 0, '合成修改');
        await edit('身份证号', 1, '000000200001010005');
        await tester.tap(find.text('开始人脸跟读认证'));
        await tester.pumpAndSettle();
        expect(submissions, [
          ['合成修改', '000000200001010005'],
        ]);
        await tester.enterText(
          find.byType(TextField).at(1),
          '0000002000010100059',
        );
        await tester.pumpAndSettle();
        expect(field('身份证号').value, '000000200001010005');
        await show(verifiedName: '合成已认证');
        expect(field('姓名').value, '合****');
        expect(editable('姓名'), false);
        await edit('身份证号', 1, '000000200001010005');
        await show(verifiedName: '合成已认证', busy: true);
        expect(editable('姓名'), false);
        expect(editable('身份证号'), false);
        await tester.tap(find.text('正在准备认证…'));
        await tester.pumpAndSettle();
        expect(submissions, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        handle.dispose();
      }
    });
  }
}
