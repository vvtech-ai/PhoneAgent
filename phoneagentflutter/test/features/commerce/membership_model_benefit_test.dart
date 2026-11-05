import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';

void main() {
  for (final level in ['BASIC', 'PLUS', 'PREMIUM']) {
    testWidgets('$level unconfigured optional benefits remain hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MembershipBenefitList(level: level, benefits: const {}),
          ),
        ),
      );
      expect(find.text('高峰优先线路', findRichText: true), findsNothing);
      expect(find.text('高峰极速优先线路', findRichText: true), findsNothing);
      expect(find.text('新模型抢先体验', findRichText: true), findsNothing);
      expect(find.text('专属呼叫号码', findRichText: true), findsNothing);
      expect(find.text('专属客服', findRichText: true), findsNothing);
    });
  }
  testWidgets(
    'published member models show names and shared models separately',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MembershipBenefitList(
              level: 'PLUS',
              benefits: {
                'modelEntitlements': [
                  {'modelId': '1', 'capability': 'REALTIME_VOICE'},
                  {'modelId': '2', 'capability': 'REALTIME_VOICE'},
                  {'modelId': '3', 'capability': 'REALTIME_VOICE'},
                ],
              },
              freeBenefits: {
                'modelEntitlements': [
                  {'modelId': '1', 'capability': 'REALTIME_VOICE'},
                  {'modelId': '2', 'capability': 'REALTIME_VOICE'},
                ],
              },
              modelNames: {
                '1': 'QwenOmniPlus',
                '2': 'Seeduplex',
                '3': 'Seeduplex V3',
              },
            ),
          ),
        ),
      );
      expect(
        find.text('会员专属模型 Seeduplex V3', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('同时支持 QwenOmniPlus、Seeduplex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
