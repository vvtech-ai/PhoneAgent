import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/membership_access_hint.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';

void main() {
  testWidgets(
    'model card replaces only duplicate entitlement status, keeping technical failures',
    (tester) async {
      for (final status in ['当前会员权益不支持该模型', '当前环境未开放该模型']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NativeModelCard(
                model: CallModel(
                  id: 'm',
                  name: '模型',
                  description: '',
                  available: false,
                  active: false,
                  status: status,
                ),
                selected: false,
                busy: false,
                onSelect: () {},
                membershipHint: '中级及以上会员可用',
              ),
            ),
          ),
        );
        expect(find.text('中级及以上会员可用'), findsOneWidget);
        expect(
          find.text(status),
          status == '当前会员权益不支持该模型' ? findsNothing : findsOneWidget,
        );
      }
    },
  );
  Map<String, Object?> permits(bool allowed) => {
    'modelEntitlements': [
      if (allowed) {'modelId': 'm', 'capability': 'REALTIME_VOICE'},
    ],
  };
  test('short hints only compress a complete suffix of enabled tiers', () {
    for (final scenario in [
      ([true, true, true], '初级及以上会员可用'),
      ([false, true, true], '中级及以上会员可用'),
      ([false, false, true], '高级会员可用'),
      ([true, false, true], '初级、高级会员可用'),
      ([true, false, false], '初级会员可用'),
      ([false, false, false], '暂无可用会员套餐'),
    ]) {
      final hint = MembershipAccessHint.model(
        current: permits(false),
        published: {
          'BASIC': permits(scenario.$1[0]),
          'PLUS': permits(scenario.$1[1]),
          'PREMIUM': permits(scenario.$1[2]),
        },
        modelId: 'm',
      );
      expect(hint.message, scenario.$2);
      expect(hint.allowed, false);
    }
  });

  Future<void> show(
    WidgetTester tester,
    String level,
    Map<String, Object?> options,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MembershipBenefitList(
          level: level,
          benefits: {
            'monthlyBasePoints': 1000,
            'monthlyBonusPoints': 500,
            'concurrentCallLimit': 2,
            'batchContactLimit': 8,
            'batchEnabled': true,
            ...options,
          },
        ),
      ),
    ),
  );
  Text title(WidgetTester tester, String text) => tester.widget<Text>(
    find.byWidgetPredicate(
      (w) => w is Text && w.textSpan?.toPlainText() == text,
    ),
  );

  testWidgets(
    'old options default all rows to regular including points and batch',
    (tester) async {
      await show(tester, 'PREMIUM', {});
      expect(title(tester, '每月到账 1,500 积分').style!.fontSize, 13);
      expect(title(tester, '8 人批量联系人任务').style!.fontSize, 13);
      expect(find.text('高峰极速优先线路', findRichText: true), findsNothing);
      expect(find.text('新模型抢先体验', findRichText: true), findsNothing);
    },
  );
  testWidgets('each row can enlarge independently of tier and adjacent rows', (
    tester,
  ) async {
    await show(tester, 'BASIC', {
      'displayOptions': {
        'monthlyPoints': {'fontSize': 'LARGE'},
        'batchCalls': {'fontSize': 'REGULAR'},
        'voiceClone': {'fontSize': 'LARGE'},
      },
    });
    expect(title(tester, '每月到账 1,500 积分').style!.fontSize, 18);
    expect(title(tester, '8 人批量联系人任务').style!.fontSize, 13);
    expect(title(tester, '声音克隆').style!.fontSize, 18);
  });
  for (final level in ['FREE', 'BASIC', 'PLUS', 'PREMIUM']) {
    testWidgets('$level optional copy follows explicit checkboxes only', (
      tester,
    ) async {
      await show(tester, level, {
        'displayOptions': {
          'priorityLine': {'visible': true, 'fontSize': 'LARGE'},
          'newModelPreview': {'visible': false},
        },
      });
      expect(title(tester, '高峰极速优先线路').style!.fontSize, 18);
      expect(find.text('新模型抢先体验', findRichText: true), findsNothing);
      await show(tester, level, {
        'displayOptions': {
          'priorityLine': {'visible': false},
          'newModelPreview': {'visible': true},
        },
      });
      expect(find.text('高峰极速优先线路', findRichText: true), findsNothing);
      expect(title(tester, '新模型抢先体验').style!.fontSize, 13);
      expect(find.textContaining('高级会员'), findsNothing);
    });
  }
}
