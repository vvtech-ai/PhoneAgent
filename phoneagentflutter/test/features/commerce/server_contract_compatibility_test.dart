import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/api_invoice_repository.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test('NON_NULL unpublished catalog omits nullable metadata', () {
    final catalog = CommerceDto.catalog({
      'configVersionId': 0,
      'revisionNo': 0,
      'products': [],
      'benefitsByLevel': {},
    });
    expect(catalog.configVersionId, 0);
    expect(catalog.revisionNo, 0);
    expect(catalog.products, isEmpty);
    expect(catalog.benefitsByLevel, isEmpty);
    expect(catalog.agreementVersion, isEmpty);
    expect(catalog.agreementUrl, isEmpty);
    expect(catalog.supportEmail, isEmpty);
  });
  test('NON_NULL free membership keeps terms and omits absent benefits', () {
    final membership = CommerceDto.membership({'level': 'FREE', 'terms': []});
    expect(membership.level, 'FREE');
    expect(membership.benefits, isNull);
    expect(membership.terms, isEmpty);
    expect(membership.currentTermId, isNull);
  });
  test('missing required empty collections do not become valid catalogs', () {
    for (final malformed in [
      null,
      {'configVersionId': 0, 'revisionNo': 0, 'benefitsByLevel': {}},
      {'configVersionId': 0, 'revisionNo': 0, 'products': []},
      {
        'configVersionId': 0,
        'revisionNo': 0,
        'products': null,
        'benefitsByLevel': {},
      },
    ]) {
      expect(() => CommerceDto.catalog(malformed), throwsFormatException);
    }
    expect(
      () => CommerceDto.membership({'level': 'FREE'}),
      throwsFormatException,
    );
  });
  test(
    'actual unpublished catalog null metadata is a closed empty catalog',
    () {
      final catalog = CommerceDto.catalog({
        'configVersionId': 0,
        'revisionNo': 0,
        'agreementVersion': null,
        'agreementUrl': null,
        'supportEmail': null,
        'products': [],
        'benefitsByLevel': {},
      });
      expect(catalog.products, isEmpty);
      expect(catalog.agreementVersion, isEmpty);
    },
  );
  test('published available offer requires a valid paid agreement', () {
    expect(
      () => CommerceDto.catalog({
        'configVersionId': 1,
        'revisionNo': 1,
        'agreementVersion': 'v1',
        'agreementUrl': 'http://example.test/agreement',
        'supportEmail': '',
        'benefitsByLevel': {},
        'products': [
          {
            'productId': 'm1',
            'name': '初级月度',
            'productType': 'MEMBERSHIP',
            'level': 'BASIC',
            'months': 1,
            'cashAmountFen': 3000,
            'basePoints': 0,
            'bonusPoints': 0,
            'currency': 'CNY',
            'channel': 'ALIPAY',
            'available': true,
            'platformProductId': null,
            'unavailableReason': null,
          },
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'actual NOT_APPLIED invoice response is a legitimate empty application',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'invoiceNo': null,
          'orderNo': 'C1',
          'status': 'NOT_APPLIED',
          'cashAmountFen': 0,
          'titleMasked': null,
          'availableFormats': [],
          'safeErrorCode': null,
        };
      expect(await ApiInvoiceRepository(backend.api).invoice('C1'), isNull);
      backend.api.close();
    },
  );
  for (final status in ['INVOICING', 'ISSUED']) {
    test('actual invoice application status $status is accepted', () {
      final invoice = ApiInvoiceRepository.parse({
        'invoiceNo': 'INV-1',
        'orderNo': 'C1',
        'status': status,
        'cashAmountFen': 3000,
        'titleMasked': '个***',
        'availableFormats': status == 'ISSUED' ? ['PDF', 'OFD', 'XML'] : [],
        'safeErrorCode': null,
      });
      expect(invoice.status, status);
    });
  }
}
