import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

HomeCard _card(int index) => HomeCard(
  id: '$index',
  title: '合成技能$index',
  subtitle: '合成说明，测试放大字号下仍可选择技能。',
  status: HomeCardStatus.enabled,
  action: HomeAction.skill,
  skillId: '$index',
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform short big text skill list scrolls to selection and closes',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        HomeCard? selected;
        await _host(
          tester,
          platform,
          List.generate(30, _card),
          false,
          (value) => selected = value,
          large: true,
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('合成技能29'),
          250,
          scrollable: find.descendant(
            of: find.byType(ContactSkillsSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('合成技能29'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('合成技能29'));
        await tester.pumpAndSettle();
        expect(selected?.skillId, '29');
        expect(find.byType(ContactSkillsSheet), findsNothing);
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.bySemanticsLabel('关闭Skill选择')),
          matchesSemantics(
            label: '关闭Skill选择',
            isButton: true,
            hasTapAction: true,
          ),
        );
        await tester.tap(find.bySemanticsLabel('关闭Skill选择'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(tester.takeException(), isNull);
      },
    );
    for (final loading in [false, true]) {
      testWidgets(
        '$platform empty first loading $loading has readable text and cancels',
        (tester) async {
          HomeCard? selected;
          await _host(
            tester,
            platform,
            [],
            loading,
            (value) => selected = value,
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          expect(
            find.text(loading ? '正在获取可用 Skill…' : '暂无可用 Skill'),
            findsOneWidget,
          );
          expect(find.byType(LinearProgressIndicator), findsNothing);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(selected, isNull);
          expect(find.byType(ContactSkillsSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('$platform cached skill remains selectable during refresh', (
      tester,
    ) async {
      HomeCard? selected;
      await _host(
        tester,
        platform,
        [_card(1)],
        true,
        (value) => selected = value,
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('正在获取可用 Skill…'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('合成技能1'));
      await tester.pumpAndSettle();
      expect(selected?.skillId, '1');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _host(
  WidgetTester tester,
  TargetPlatform platform,
  List<HomeCard> cards,
  bool loading,
  ValueChanged<HomeCard?> onResult, {
  bool large = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          child: const Text('打开'),
          onPressed: () async {
            final result = await showModalBottomSheet<HomeCard>(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFFFBFCFF),
              builder: (sheetContext) => ContactSkillsSheet(
                contactName: '合成联系人',
                cards: cards,
                loading: loading,
                preview: false,
                onClose: () => Navigator.pop(sheetContext),
                onSelect: (card) => Navigator.pop(sheetContext, card),
              ),
            );
            onResult(result);
          },
        ),
      ),
    ),
  ),
);
