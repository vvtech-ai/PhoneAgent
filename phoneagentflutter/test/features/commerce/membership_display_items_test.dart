import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';
import 'membership_contract_v2_test.dart' show fixture;

Map<String, Object?> _benefits({Object? items, bool includeItems = true}) => {
  'monthlyBasePoints': 3900,
  'monthlyBonusPoints': 600,
  'batchEnabled': false,
  'concurrentCallLimit': 1,
  'cloneEntitlements': {'enabled': false},
  if (includeItems) 'displayItems': items,
  'displayOptions': {
    'monthlyPoints': {'fontSize': 'LARGE'},
  },
};

Map<String, Object?> _item(String id, String title, String font) => {
  'id': id,
  'title': title,
  'description': '$title的详细介绍',
  'fontSize': font,
};

Future<void> _show(
  WidgetTester tester,
  Map<String, Object?> benefits, {
  String level = 'BASIC',
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: MembershipBenefitList(level: level, benefits: benefits),
          ),
        ),
      ),
    ),
  ),
);

Text _title(WidgetTester tester, String text) => tester.widget<Text>(
  find.byWidgetPredicate(
    (widget) => widget is Text && widget.textSpan?.toPlainText() == text,
  ),
);

void main() {
  testWidgets('仅月积分数值为原蓝色，周围文字和权益保持原标题与颜色', (tester) async {
    const title =
        '可用模型 QwenOmniPlus、Seeduplex、Seeduplex V3、IndexTTS 2.5 实时通话（千问听略）、Qwen Audio 3.1 实时通话';
    for (final large in [false, true]) {
      final benefits = _benefits(
        items: [_item('models', title, large ? 'LARGE' : 'REGULAR')],
      );
      benefits['displayOptions'] = {
        'monthlyPoints': {'fontSize': large ? 'LARGE' : 'REGULAR'},
      };
      await _show(tester, benefits);
      expect(
        _title(tester, '每月到账 4,500 积分').style!.color,
        const Color(0xFF202532),
      );
      final spans =
          (_title(tester, '每月到账 4,500 积分').textSpan! as TextSpan).children!;
      expect(spans.map((span) => span.toPlainText()).toList(), [
        '每月到账 ',
        '4,500',
        ' 积分',
      ]);
      expect(spans[1].style!.color, const Color(0xFF3478F5));
      expect(spans[0].style?.color, isNull);
      expect(spans[2].style?.color, isNull);
      expect(_title(tester, title).style!.color, const Color(0xFF202532));
      expect(_title(tester, title).style!.fontSize, large ? 18 : 13);
      expect(
        tester.widget<Text>(find.text('其中含赠送 600 积分')).style!.color,
        large ? const Color(0xFF7D8491) : const Color(0xFF858991),
      );
      expect(tester.takeException(), isNull);
    }
  });
  test(
    'catalog and current membership preserve copy and their own point values',
    () {
      final items = [_item('new-model', '发布后的权益介绍', 'LARGE')];
      final catalog = CommerceDto.catalog({
        'configVersionId': 7,
        'revisionNo': 4,
        'products': [],
        'benefitsByLevel': {'BASIC': _benefits(items: items)},
      });
      final current = CommerceDto.membership({
        ...fixture('current'),
        'benefits': {..._benefits(items: items), 'monthlyBasePoints': 2800},
      });
      expect(catalog.benefitsByLevel['BASIC']!['displayItems'], items);
      expect(current.benefits!['displayItems'], items);
      expect(catalog.benefitsByLevel['BASIC']!['monthlyBasePoints'], 3900);
      expect(current.benefits!['monthlyBasePoints'], 2800);
      expect(current.benefits!['monthlyBonusPoints'], 600);
    },
  );

  testWidgets(
    'published items replace generated copy, retaining order and styles',
    (tester) async {
      final items = [
        _item('clone', '用自己的声音通话', 'REGULAR'),
        _item('preview', '新模型优先体验', 'LARGE'),
      ];
      await _show(tester, _benefits(items: items));

      expect(find.text('用自己的声音通话', findRichText: true), findsOneWidget);
      expect(find.text('新模型优先体验', findRichText: true), findsOneWidget);
      expect(find.text('声音克隆', findRichText: true), findsNothing);
      expect(find.text('单路 Agent 外呼', findRichText: true), findsNothing);
      expect(_title(tester, '用自己的声音通话').style!.fontSize, 13);
      expect(_title(tester, '新模型优先体验').style!.fontSize, 18);
      expect(
        tester.widget<Text>(find.text('用自己的声音通话的详细介绍')).style!.fontSize,
        11,
      );
      expect(
        tester.widget<Text>(find.text('新模型优先体验的详细介绍')).style!.fontSize,
        13,
      );
      expect(
        tester.getTopLeft(find.text('用自己的声音通话', findRichText: true)).dy,
        lessThan(
          tester.getTopLeft(find.text('新模型优先体验', findRichText: true)).dy,
        ),
      );

      await _show(tester, _benefits(items: items.reversed.toList()));
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('membership-benefit-preview')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('membership-benefit-clone')),
              )
              .dy,
        ),
      );
      expect(_title(tester, '新模型优先体验').style!.fontSize, 18);
      expect(_title(tester, '用自己的声音通话').style!.fontSize, 13);
    },
  );

  testWidgets('empty published list keeps only real read-only monthly points', (
    tester,
  ) async {
    await _show(tester, _benefits(items: []));
    expect(find.text('每月到账 4,500 积分', findRichText: true), findsOneWidget);
    expect(find.text('其中含赠送 600 积分'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('声音克隆', findRichText: true), findsNothing);
    expect(find.text('单路 Agent 外呼', findRichText: true), findsNothing);
    expect(_title(tester, '每月到账 4,500 积分').style!.fontSize, 18);
    expect(tester.widget<Text>(find.text('其中含赠送 600 积分')).style!.fontSize, 13);

    await _show(tester, _benefits(items: []), level: 'FREE');
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('missing and null displayItems preserve old presentation', (
    tester,
  ) async {
    for (final benefits in [_benefits(includeItems: false), _benefits()]) {
      await _show(tester, benefits);
      expect(find.text('声音克隆', findRichText: true), findsOneWidget);
      expect(find.text('单路 Agent 外呼', findRichText: true), findsOneWidget);
      expect(find.text('每月到账 4,500 积分', findRichText: true), findsOneWidget);
    }
  });

  testWidgets(
    'month row cannot be replaced by a custom item and long copy wraps',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const longTitle = '让人工智能使用自己的声音完成多种场景中的电话沟通服务';
      await _show(
        tester,
        _benefits(
          items: [
            _item('monthlyPoints', '虚假的每月到账', 'LARGE'),
            {
              ..._item('long', longTitle, 'LARGE'),
              'description': '这是一段较长的权益说明，窄屏和放大字体时仍然应该完整展示，保持清晰的阅读层级。',
            },
          ],
        ),
        scale: 2,
      );
      expect(find.text('虚假的每月到账', findRichText: true), findsNothing);
      expect(find.text('每月到账 4,500 积分', findRichText: true), findsOneWidget);
      expect(find.text(longTitle, findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('membership-benefit-long')))
            .right,
        lessThanOrEqualTo(300),
      );
    },
  );
}
