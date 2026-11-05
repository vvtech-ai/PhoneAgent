import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/widgets/identity_editor.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform gender buttons expose selection and busy barrier', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var gender = '不透露';
      var busy = false;
      var changes = 0;
      late StateSetter update;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return IdentityEditor(
                      draft: IdentityDraft(name: '合成身份', gender: gender),
                      busy: busy,
                      verified: false,
                      onName: (_) {},
                      onPhone: (_) {},
                      onGender: (value) => setState(() {
                        gender = value;
                        changes++;
                      }),
                      onSave: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        SemanticsNode button(String label) {
          final matches = <SemanticsNode>[];
          void walk(SemanticsNode node) {
            if (node.label == label && node.hasFlag(SemanticsFlag.isButton)) {
              matches.add(node);
            }
            node.visitChildren((child) {
              walk(child);
              return true;
            });
          }

          walk(
            tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          expect(matches, hasLength(1));
          return matches.single;
        }

        void check() {
          for (final label in ['不透露', '男', '女']) {
            final node = button(label);
            expect(node.hasFlag(SemanticsFlag.isSelected), label == gender);
            expect(node.hasFlag(SemanticsFlag.isEnabled), !busy);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              !busy,
            );
          }
        }

        check();
        final node = button('男');
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(gender, '男');
        expect(changes, 1);
        check();
        update(() => busy = true);
        await tester.pumpAndSettle();
        check();
        expect(changes, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        handle.dispose();
      }
    });
  }
}
