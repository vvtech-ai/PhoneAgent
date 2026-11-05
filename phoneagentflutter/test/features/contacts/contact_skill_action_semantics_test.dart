import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

const _card = HomeCard(
  id: 'synthetic',
  title: '合成技能',
  subtitle: '合成说明',
  status: HomeCardStatus.enabled,
  action: HomeAction.skill,
  skillId: 'synthetic-skill',
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final refreshing in [false, true]) {
      testWidgets('$platform skill named action while refresh $refreshing', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final chosen = <HomeCard>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: ContactSkillsSheet(
                  contactName: '合成联系人',
                  cards: const [_card],
                  loading: refreshing,
                  preview: false,
                  onClose: () {},
                  onSelect: chosen.add,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final action = find.bySemanticsLabel('合成技能，合成说明');
          expect(action, findsOneWidget);
          final node = tester.getSemantics(action);
          expect(node.hasFlag(SemanticsFlag.isButton), true);
          expect(node.hasFlag(SemanticsFlag.isEnabled), true);
          expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);
          final buttons = <SemanticsNode>[];
          void visit(SemanticsNode value) {
            if (value.hasFlag(SemanticsFlag.isButton)) buttons.add(value);
            value.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(node);
          expect(buttons, hasLength(1));
          tester.binding.renderViews.single.owner!.semanticsOwner!
              .performAction(node.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(chosen, [_card]);
          chosen.clear();
          await tester.tap(find.text('合成技能'));
          await tester.pumpAndSettle();
          expect(chosen, [_card]);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
