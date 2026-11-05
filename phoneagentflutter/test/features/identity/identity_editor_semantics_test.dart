import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/widgets/identity_editor.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform identity named fields preserve editing barriers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        var name = '', phone = '';
        Future<void> show({bool verified = false, bool busy = false}) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: IdentityEditor(
                    draft: const IdentityDraft(
                      name: '合成身份',
                      contactPhone: '13800000000',
                    ),
                    verified: verified,
                    busy: busy,
                    onName: (value) => name = value,
                    onPhone: (value) => phone = value,
                    onGender: (_) {},
                    onSave: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        SemanticsNode field(String label) {
          final matches = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            if (node.hasFlag(SemanticsFlag.isTextField) &&
                node.label.contains(label)) {
              matches.add(node);
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
          expect(matches, hasLength(1), reason: label);
          return matches.single;
        }

        bool editable(String label) =>
            field(label).getSemanticsData().hasAction(SemanticsAction.setText);
        await show();
        expect(field('姓名').value, '合成身份');
        expect(field('手机号码').value, '13800000000');
        await tester.tap(find.byKey(const ValueKey('identity-name')));
        await tester.pumpAndSettle();
        expect(field('姓名').hasFlag(SemanticsFlag.isFocused), true);
        expect(editable('姓名'), true);
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          field('姓名').id,
          SemanticsAction.setText,
          '合成修改',
        );
        await tester.pumpAndSettle();
        expect(name, '合成修改');
        expect(field('姓名').value, '合成修改');
        await tester.tap(find.byKey(const ValueKey('identity-phone')));
        await tester.pumpAndSettle();
        expect(field('手机号码').hasFlag(SemanticsFlag.isFocused), true);
        expect(editable('手机号码'), true);
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          field('手机号码').id,
          SemanticsAction.setText,
          '13900000000',
        );
        await tester.pumpAndSettle();
        expect(phone, '13900000000');
        await show(verified: true);
        expect(editable('姓名'), false);
        expect(editable('手机号码'), true);
        await show(busy: true);
        expect(editable('姓名'), false);
        expect(editable('手机号码'), false);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        handle.dispose();
      }
    });
  }
}
