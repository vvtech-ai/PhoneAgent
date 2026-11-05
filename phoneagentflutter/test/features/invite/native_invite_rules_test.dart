import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rule_paragraphs.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rules_sheet.dart';

void main() {
  test('native paragraph boundaries preserve numbering and internal lines', () {
    expect(
      inviteRuleParagraphs('说明\r\n继续说明\r\n\r\n 1、 第一条\n内部换行\n2） 第二条\n\n尾注'),
      ['说明\n继续说明', ' 1、 第一条\n内部换行', '2） 第二条', '尾注'],
    );
    expect(inviteRuleParagraphs('3. 三\n4． 四\n5) 五'), ['3. 三', '4． 四', '5) 五']);
    expect(inviteRuleParagraphs(' \n\t'), isEmpty);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform numbered rules layout and safe acknowledgement large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          if (large) {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
          }
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          const first = '1、 第一条运营规则保持原文，长行继续显示。\n条目内补充说明。';
          const second = '2） 第二条规则';
          final activity = InviteActivity(
            id: 'synthetic',
            name: '合成活动',
            rules:
                '$first\n$second\n\n${List.filled(16, '规则末尾补充说明').join('\n')}',
            inviterPoints: 1,
            inviteePoints: 1,
            quota: 1,
          );
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Builder(
                  builder: (root) => Scaffold(
                    body: TextButton(
                      child: const Text('打开'),
                      onPressed: () => showInviteRules(root, activity),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            expect(find.byType(SelectableText), findsNothing);
            final one = find.bySemanticsLabel(first);
            final two = find.bySemanticsLabel(second);
            expect(
              tester.getTopLeft(two).dy - tester.getBottomLeft(one).dy,
              12,
            );
            final prefix = find.text('1、');
            final body = find.text('第一条运营规则保持原文，长行继续显示。\n条目内补充说明。');
            expect(
              tester.getTopLeft(body).dx - tester.getTopRight(prefix).dx,
              4,
            );
            final style = tester.widget<Text>(body).style!;
            expect(style.fontSize, 14);
            expect(style.height, 1.5);
            expect(tester.getTopLeft(body).dy, tester.getTopLeft(prefix).dy);
            final button = find.byType(FilledButton);
            final old = tester.widget<FilledButton>(button).onPressed!;
            final sheetContext = tester.element(button);
            Navigator.of(sheetContext).push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('覆盖页')),
              ),
            );
            await tester.pumpAndSettle();
            old();
            await tester.pumpAndSettle();
            expect(find.text('覆盖页'), findsOneWidget);
            Navigator.of(sheetContext).pop();
            await tester.pumpAndSettle();
            old();
            old();
            await tester.pumpAndSettle();
            expect(find.text('活动规则'), findsNothing);
            expect(find.text('打开'), findsOneWidget);
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            old();
            await tester.pumpAndSettle();
            expect(find.text('活动规则'), findsOneWidget);
            await tester.tap(find.text('我知道了'));
            await tester.pumpAndSettle();
            expect(find.text('打开'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(
              const MaterialApp(
                home: Scaffold(body: InviteRuleParagraphs(text: '  \n')),
              ),
            );
            expect(find.text('活动规则暂不可用，请稍后刷新。'), findsOneWidget);
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
