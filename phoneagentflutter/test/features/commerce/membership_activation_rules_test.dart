import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_details.dart';
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  for (final type in ['new', 'renew']) {
    for (final level in ['BASIC', 'PLUS', 'PREMIUM']) {
      testWidgets('$level $type payment rule visibility and expansion', (
        tester,
      ) async {
        final data = fixture('quote-$type');
        final quote = CommerceDto.quote({
          ...data,
          'membershipPreview': {
            ...data['membershipPreview'] as Map,
            'targetLevel': level,
          },
          'quoteId': 'q',
          'productId': 'm',
          'configVersionId': 1,
          'cashAmountFen': 4000,
          'currency': 'CNY',
          'expiresAt': '2099-01-01T00:00:00+08:00',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MembershipConfirmationDetails(
                  quote: quote,
                  productName: '会员',
                  displayPrice: '¥40.00',
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('查看生效规则'),
          level == 'PREMIUM' ? findsNothing : findsOneWidget,
        );
        if (level != 'PREMIUM') {
          expect(
            find.textContaining(
              type == 'new' ? '本套餐剩余权益会暂停保留' : '预计日期按当前已购套餐测算',
            ),
            findsNothing,
          );
          await tester.tap(find.text('查看生效规则'));
          await tester.pump();
          expect(
            find.textContaining(
              type == 'new' ? '本套餐剩余权益会暂停保留' : '预计日期按当前已购套餐测算',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('查看生效规则'));
          await tester.pump();
          expect(
            find.textContaining(
              type == 'new' ? '本套餐剩余权益会暂停保留' : '预计日期按当前已购套餐测算',
            ),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
