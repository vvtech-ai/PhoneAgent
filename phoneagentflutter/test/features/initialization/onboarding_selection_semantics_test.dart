import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/presentation/widgets/login_agreement.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/initialization/domain/initialization_gateway.dart';
import 'package:phone_agent/features/initialization/presentation/widgets/initialization_fields.dart';

List<SemanticsNode> nodes(WidgetTester tester) {
  final result = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    result.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return result;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final kind in ['agreement', 'gender', 'model']) {
      testWidgets('$platform $kind has one named actionable selection', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var busy = false, accepted = false;
        var selected = kind == 'gender' ? '不透露' : 'first';
        var writes = 0;
        late StateSetter update;
        const catalog = InitializationCatalog('first', [
          InitializationModel('first', '合成模型一', '推荐模型', recommended: true),
          InitializationModel('second', '合成模型二', '普通模型'),
          InitializationModel('disabled', '不可用模型', '不可用', enabled: false),
        ]);
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      void choose(String value) => setState(() {
                        selected = value;
                        writes++;
                      });
                      return switch (kind) {
                        'agreement' => LoginAgreement(
                          accepted: accepted,
                          error: false,
                          enabled: !busy,
                          onChanged: (value) => setState(() {
                            accepted = value;
                            writes++;
                          }),
                          openDocument: (_) {},
                        ),
                        'gender' => InitializationIdentityFields(
                          draft: IdentityDraft(name: '合成身份', gender: selected),
                          busy: busy,
                          onName: (_) {},
                          onPhone: (_) {},
                          onGender: choose,
                        ),
                        _ => InitializationModelCards(
                          catalog: catalog,
                          selected: selected,
                          busy: busy,
                          onSelect: choose,
                        ),
                      };
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          SemanticsNode selection(String label) {
            final matches = nodes(tester)
                .where(
                  (node) =>
                      node.label.startsWith(label) &&
                      node.hasFlag(
                        kind == 'agreement'
                            ? SemanticsFlag.hasCheckedState
                            : SemanticsFlag.isButton,
                      ),
                )
                .toList();
            expect(matches, hasLength(1), reason: label);
            return matches.single;
          }

          final label = switch (kind) {
            'agreement' => '同意用户协议和隐私政策',
            'gender' => '男',
            _ => '合成模型二',
          };
          void check() {
            final choices = nodes(tester)
                .where(
                  (node) => node.hasFlag(
                    kind == 'agreement'
                        ? SemanticsFlag.hasCheckedState
                        : SemanticsFlag.isButton,
                  ),
                )
                .toList();
            expect(choices, hasLength(kind == 'agreement' ? 1 : 3));
            final node = selection(label);
            expect(node.hasFlag(SemanticsFlag.isEnabled), !busy);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              !busy,
            );
            if (kind == 'agreement') {
              expect(node.hasFlag(SemanticsFlag.isChecked), accepted);
              expect(find.bySemanticsLabel('《用户协议》'), findsOneWidget);
              expect(find.bySemanticsLabel('《隐私政策》'), findsOneWidget);
            } else {
              expect(
                choices.where((node) => node.hasFlag(SemanticsFlag.isSelected)),
                hasLength(1),
              );
              expect(
                node.hasFlag(SemanticsFlag.isSelected),
                selected == (kind == 'gender' ? '男' : 'second'),
              );
            }
            if (kind == 'model') {
              final disabled = selection('不可用模型');
              expect(disabled.hasFlag(SemanticsFlag.isEnabled), isFalse);
              expect(
                disabled.getSemanticsData().hasAction(SemanticsAction.tap),
                isFalse,
              );
            }
          }

          check();
          tester.binding.renderViews.single.owner!.semanticsOwner!
              .performAction(selection(label).id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(writes, 1);
          check();
          update(() => busy = true);
          await tester.pumpAndSettle();
          check();
          expect(writes, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          handle.dispose();
        }
      });
    }
  }
}
