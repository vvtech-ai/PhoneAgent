import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_display.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_price_options.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;
import 'membership_reference_fixture.dart';

void main() {
  test('structured periods use card names and keep other duration units', () {
    expect([1, 3, 12].map(periodName), ['月卡', '季卡', '年卡']);
    expect(periodName(6), '6 个月');
  });

  test('historical member snapshots are formatted without rewriting facts', () {
    for (final entry in {1: '月卡', 3: '季卡', 12: '年卡'}.entries) {
      final order = CommerceDto.order({
        ...orderJson(),
        'productName': '连续包月',
        'membershipLevel': 'BASIC',
        'membershipMonths': entry.key,
      });
      expect(orderProductLabel(order), '初级会员·${entry.value}');
      expect(order.productName, '连续包月');
    }
    final points = CommerceDto.order({
      ...orderJson(),
      'productType': 'POINTS_PACK',
      'productName': '包月专享积分',
    });
    expect(orderProductLabel(points), '包月专享积分');
    final missing = CommerceDto.order({
      ...orderJson(),
      'productName': '连续包月',
      'membershipLevel': null,
      'membershipMonths': null,
    });
    expect(orderProductLabel(missing), '会员套餐');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform omits relationship labels for every target and duration',
      (tester) async {
        for (final current in [
          'FREE',
          'BASIC',
          'PLUS',
          'PREMIUM',
          'UNKNOWN',
          null,
        ]) {
          for (final target in ['BASIC', 'PLUS', 'PREMIUM']) {
            for (final selected in [1, 3, 12]) {
              final state = labelState(
                current: current,
                target: target,
                months: selected,
              );
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: MembershipPriceOptions(
                      state: state,
                      onMonths: (_) {},
                    ),
                  ),
                ),
              );
              for (final label in ['月卡', '季卡', '年卡']) {
                expect(find.text(label), findsOneWidget);
              }
              expect(find.text('升级'), findsNothing);
              expect(find.text('续购'), findsNothing);
              expect(tester.takeException(), isNull);
            }
          }
        }
      },
    );
    testWidgets(
      '$platform card names remain usable at narrow width and large text',
      (tester) async {
        for (final width in [320.0, 375.0, 430.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          for (final scale in [1.0, 2.0]) {
            var selected = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MembershipPriceOptions(
                        state: labelState(current: 'PLUS', target: 'BASIC'),
                        onMonths: (months) => selected = months,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('季卡'));
            expect(selected, 3);
            expect(find.text('续购'), findsNothing);
            expect(find.text('升级'), findsNothing);
            expect(tester.takeException(), isNull);
          }
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }

  testWidgets(
    'active, paused and queued projections do not add relationship labels',
    (tester) async {
      final state = labelState(current: 'PREMIUM', target: 'PLUS');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MembershipPriceOptions(
              state: CatalogState(
                catalog: state.catalog,
                selectedLevel: 'PLUS',
                membership: CommerceDto.membership({
                  ...fixture('current'),
                  'level': 'BASIC',
                }),
              ),
              onMonths: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('续购'), findsNothing);
      expect(find.text('升级'), findsNothing);
    },
  );
}

CatalogState labelState({
  String? current,
  required String target,
  int months = 1,
}) {
  return CatalogState(
    catalog: membershipReferenceFixture(target).catalog,
    selectedLevel: target,
    selectedMonths: months,
    membership: current == null
        ? null
        : MembershipCurrent(
            level: current,
            entitlementVersionId: 1,
            benefits: null,
            terms: const [],
          ),
  );
}
