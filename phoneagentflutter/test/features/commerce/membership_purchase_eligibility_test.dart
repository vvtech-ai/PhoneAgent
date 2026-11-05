import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'membership_contract_v2_test.dart' show fixture;
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_offer.dart';

const hint = '升级保留原会员时长，购买更长套餐可延长有效期。';
ProductOffer offer(String level, int months, {String type = 'MEMBERSHIP'}) =>
    ProductOffer(
      productId: '$level-$months',
      name: '会员',
      productType: type,
      level: level,
      months: months,
      cashAmountFen: 1000,
      basePoints: 0,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: true,
    );
MembershipCurrent member(String level, int? months) => MembershipCurrent(
  level: level,
  currentMonths: months,
  entitlementVersionId: 1,
  benefits: const {},
  terms: const [],
);
CatalogState state(MembershipCurrent? current, ProductOffer target) =>
    CatalogState(
      catalog: CommerceCatalog(
        configVersionId: 1,
        revisionNo: 1,
        agreementVersion: 'v1',
        agreementUrl: '',
        supportEmail: '',
        products: [target],
      ),
      membership: current,
      selectedLevel: target.level!,
      selectedMonths: target.months!,
      channelAvailable: true,
    );

void main() {
  for (final currentLevel in membershipLevels) {
    for (final currentMonths in [1, 3, 12]) {
      for (final targetLevel in membershipLevels.skip(1)) {
        for (final targetMonths in [1, 3, 12]) {
          test(
            '$currentLevel/$currentMonths -> $targetLevel/$targetMonths qualification',
            () {
              final target = offer(targetLevel, targetMonths);
              final rank = membershipLevels.indexOf(currentLevel);
              final targetRank = membershipLevels.indexOf(targetLevel);
              final allowed =
                  rank == 0 ||
                  targetRank > rank ||
                  (targetRank == rank && targetMonths > currentMonths);
              expect(
                state(
                  member(currentLevel, currentMonths),
                  target,
                ).purchasable(target),
                allowed,
              );
            },
          );
        }
      }
    }
  }
  test(
    'unknown membership and missing same-level period do not allow new purchase',
    () {
      final target = offer('PLUS', 3);
      expect(state(null, target).newPurchaseEnabled(target), isFalse);
      expect(
        state(member('PLUS', null), target).newPurchaseEnabled(target),
        isFalse,
      );
      expect(
        state(member('UNKNOWN', 1), target).newPurchaseEnabled(target),
        isFalse,
      );
      expect(
        state(member('BASIC', null), target).newPurchaseEnabled(target),
        isTrue,
      );
    },
  );
  test('retained and queued plans do not replace the active membership', () {
    final current = CommerceDto.membership(fixture('current'));
    expect(current.retainedEntitlements, isNotEmpty);
    expect(current.queuedEntitlements, isNotEmpty);
    final lower = offer('PLUS', 12);
    expect(state(current, lower).newPurchaseEnabled(lower), isFalse);
    final longer = offer('PREMIUM', 12);
    expect(state(current, longer).newPurchaseEnabled(longer), isTrue);
  });
  test('new-purchase gate does not invalidate ongoing checkout checks', () {
    final target = offer('PLUS', 3);
    final refreshed = state(member('PLUS', 3), target);
    expect(refreshed.newPurchaseEnabled(target), isFalse);
    expect(refreshed.purchaseEnabled(target), isTrue);
  });
  test('points packs retain their existing purchase conditions', () {
    final pack = offer('BASIC', 1, type: 'POINTS_PACK');
    expect(state(member('PREMIUM', 12), pack).purchasable(pack), isTrue);
  });
  for (final width in [375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'button labels and disabled clicks, width $width scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var buys = 0;
          for (final scenario in [
            ('FREE', 1, 'BASIC', 1, '购买会员', true),
            ('PLUS', 1, 'PLUS', 1, '当前会员', false),
            ('PLUS', 1, 'PLUS', 12, '升级会员', true),
            ('PLUS', 12, 'PLUS', 1, '购买会员', false),
            ('PLUS', 1, 'BASIC', 12, '购买会员', false),
            ('PLUS', 12, 'PREMIUM', 1, '升级会员', true),
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: MembershipOffer(
                      state: state(
                        member(scenario.$1, scenario.$2),
                        offer(scenario.$3, scenario.$4),
                      ),
                      onMonths: (_) {},
                      onBuy: () => buys++,
                      onSupport: () {},
                    ),
                  ),
                ),
              ),
            );
            final button = find.widgetWithText(FilledButton, scenario.$5);
            expect(button, findsOneWidget);
            expect(
              tester.widget<FilledButton>(button).onPressed != null,
              scenario.$6,
            );
            expect(find.text(hint), findsOneWidget);
            final before = buys;
            await tester.ensureVisible(button);
            await tester.tap(button);
            expect(buys, before + (scenario.$6 ? 1 : 0));
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
