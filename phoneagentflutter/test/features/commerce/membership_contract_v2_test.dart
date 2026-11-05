import 'package:crypto/crypto.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import '../../support/synthetic_account_api.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';

Map<String, Object?> fixture(String name) => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/features/commerce/fixtures/membership_v2/$name.json',
        ).readAsStringSync(),
      )
      as Map,
);
void main() {
  test('canonical fixture snapshot matches its frozen SHA256 manifest', () {
    const directory = 'test/features/commerce/fixtures/membership_v2';
    final manifest =
        jsonDecode(File('$directory/SHA256SUMS.json').readAsStringSync())
            as Map;
    expect(
      sha256
          .convert(File('$directory/SHA256SUMS.json').readAsBytesSync())
          .toString(),
      '686efd49686990b9ef2f363d59995a0bad8736a050a3ee3f819e644d855e388c',
    );
    for (final entry in manifest.entries) {
      expect(
        sha256
            .convert(File('$directory/${entry.key}').readAsBytesSync())
            .toString(),
        entry.value,
        reason: entry.key as String,
      );
    }
  });

  test(
    'catalog advertises v2 without replacing published platform switches',
    () {
      final catalog = CommerceDto.catalog({
        'configVersionId': 1,
        'revisionNo': 1,
        'products': [],
        'benefitsByLevel': {},
        'membershipRuleVersion': 'PAUSE_QUEUE_V1',
        'membershipProtocolVersion': 2,
        'membershipEnabled': false,
        'pointsPackEnabled': true,
      });
      expect(catalog.membershipProtocolVersion, 2);
      expect(catalog.membershipRuleVersion, 'PAUSE_QUEUE_V1');
      expect(catalog.membershipEnabled, isFalse);
      expect(catalog.pointsPackEnabled, isTrue);
    },
  );

  test(
    'quote request declares protocol2 without changing original order identity',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          ...fixture('quote-lower_queued'),
          'quoteId': 'q',
          'productId': 'm',
          'configVersionId': 1,
          'cashAmountFen': 4000,
          'currency': 'CNY',
          'expiresAt': '2099-01-01T00:00:00+08:00',
        };
      final quote = await ApiCommerceRepository(backend.api).quote('m', 1);
      final body = backend.requests.single.data as Map;
      expect(body['membershipProtocolVersion'], 2);
      expect(body['productId'], 'm');
      expect(quote.purchaseType, 'LOWER_QUEUED');
      backend.api.close();
    },
  );

  test(
    'unsafe server point values and contradictory preview cannot be purchased',
    () {
      final base = <String, Object?>{
        ...fixture('quote-new'),
        'quoteId': 'q',
        'productId': 'm',
        'configVersionId': 1,
        'cashAmountFen': 4000,
        'currency': 'CNY',
        'expiresAt': '2099-01-01T00:00:00+08:00',
      };
      expect(
        () => CommerceDto.quote({
          ...base,
          'membershipPreview': {
            ...(base['membershipPreview'] as Map),
            'firstGrantPoints': 9007199254740992,
          },
        }),
        throwsFormatException,
      );
      expect(
        () => CommerceDto.quote({...base, 'purchaseType': 'RENEW'}),
        throwsFormatException,
      );
    },
  );

  test(
    'four server previews preserve purchase type and nullable queue time',
    () {
      for (final type in ['new', 'upgrade', 'renew', 'lower_queued']) {
        final dynamic quote = CommerceDto.quote({
          ...fixture('quote-$type'),
          'quoteId': 'q',
          'productId': 'm',
          'configVersionId': 1,
          'cashAmountFen': 4000,
          'currency': 'CNY',
          'expiresAt': '2026-10-14T10:05:00+08:00',
        });
        expect(quote.membershipPreview.purchaseType, type.toUpperCase());
        expect(quote.membershipPreview.membershipVersion, '18');
        if (type == 'lower_queued') {
          expect(
            quote.membershipPreview.precedingEntitlements.first.entitlementId,
            '203',
          );
          expect(quote.membershipPreview.estimatedStartsAt, isNull);
        }
      }
    },
  );
  test('current preserves paused seconds and unknown queued seconds', () {
    final dynamic current = CommerceDto.membership(fixture('current'));
    expect(current.activeEntitlement.entitlementId, '203');
    expect(current.retainedEntitlements.single.remainingSeconds, 1814400);
    expect(current.queuedEntitlements.single.remainingSeconds, isNull);
    expect(current.queuedEntitlements.single.firstActivatedAt, isNull);
  });
}
