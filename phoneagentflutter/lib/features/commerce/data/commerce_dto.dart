import 'membership_v2_dto.dart';

import '../domain/commerce_catalog.dart';
import '../domain/commerce_order.dart';
import '../domain/payment_launcher.dart';
import '../domain/platform_payment_amount.dart';

class CommerceDto {
  static Map<String, Object?> object(Object? value) {
    if (value is! Map) throw const FormatException('Expected object');
    return Map<String, Object?>.from(value);
  }

  static String text(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! String) throw FormatException('Invalid $k');
    return v;
  }

  static String? optionalText(Map<String, Object?> m, String k) =>
      m[k] == null ? null : text(m, k);
  static int integer(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! int || v < 0) throw FormatException('Invalid $k');
    return v;
  }

  static int? optionalInteger(Map<String, Object?> m, String k) =>
      m[k] == null ? null : integer(m, k);

  static bool boolean(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! bool) throw FormatException('Invalid $k');
    return v;
  }

  static DateTime date(Map<String, Object?> m, String k) {
    final value = text(m, k);
    // A server LocalDateTime is Shanghai wall time, independent of device zone.
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
    return DateTime.parse(hasOffset ? value : '$value+08:00');
  }

  static DateTime? optionalDate(Map<String, Object?> m, String k) =>
      m[k] == null ? null : date(m, k);
  static List<Object?> list(Map<String, Object?> m, String k) {
    if (m[k] is! List) throw FormatException('Invalid $k');
    return List<Object?>.from(m[k] as List);
  }

  static String oneOf(
    Map<String, Object?> m,
    String k,
    Iterable<String> values,
  ) {
    final v = text(m, k);
    if (!values.contains(v)) throw FormatException('Invalid $k');
    return v;
  }

  static CommerceCatalog catalog(Object? value) {
    final m = object(value);
    final configVersionId = integer(m, 'configVersionId');
    final products = List<ProductOffer>.unmodifiable(
      list(m, 'products').map(product),
    );
    final empty = products.isEmpty;
    final agreementVersion = empty
        ? optionalText(m, 'agreementVersion') ?? ''
        : text(m, 'agreementVersion');
    final agreementUrl = empty
        ? optionalText(m, 'agreementUrl') ?? ''
        : text(m, 'agreementUrl');
    if (products.any((p) => p.available)) {
      final uri = Uri.tryParse(agreementUrl);
      if (configVersionId == 0 ||
          agreementVersion.trim().isEmpty ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid sale agreement');
      }
    }
    return CommerceCatalog(
      configVersionId: configVersionId,
      revisionNo: integer(m, 'revisionNo'),
      agreementVersion: agreementVersion,
      agreementUrl: agreementUrl,
      supportEmail: empty
          ? optionalText(m, 'supportEmail') ?? ''
          : text(m, 'supportEmail'),
      products: products,
      membershipRuleVersion: optionalText(m, 'membershipRuleVersion'),
      membershipProtocolVersion: optionalInteger(
        m,
        'membershipProtocolVersion',
      ),
      membershipEnabled:
          !m.containsKey('membershipEnabled') ||
          boolean(m, 'membershipEnabled'),
      pointsPackEnabled:
          !m.containsKey('pointsPackEnabled') ||
          boolean(m, 'pointsPackEnabled'),
      benefitsByLevel: Map<String, Map<String, Object?>>.unmodifiable(
        object(m['benefitsByLevel']).map(
          (key, value) =>
              MapEntry(key, Map<String, Object?>.unmodifiable(object(value))),
        ),
      ),
    );
  }

  static ProductOffer product(Object? value) {
    final m = object(value);
    final type = oneOf(m, 'productType', ['MEMBERSHIP', 'POINTS_PACK']);
    final level = m['level'] == null
        ? null
        : oneOf(m, 'level', membershipLevels);
    final months = optionalInteger(m, 'months');
    final originalCashAmountFen = optionalInteger(m, 'originalCashAmountFen');
    if (originalCashAmountFen == 0) {
      throw const FormatException('Invalid originalCashAmountFen');
    }
    if (type == 'MEMBERSHIP' &&
        (level == null ||
            level == 'FREE' ||
            !const {1, 3, 12}.contains(months))) {
      throw const FormatException('Invalid membership product');
    }
    return ProductOffer(
      productId: text(m, 'productId'),
      name: text(m, 'name'),
      productType: type,
      level: level,
      months: months,
      cashAmountFen: integer(m, 'cashAmountFen'),
      originalCashAmountFen: originalCashAmountFen,
      basePoints: integer(m, 'basePoints'),
      bonusPoints: integer(m, 'bonusPoints'),
      currency: text(m, 'currency'),
      channel: text(m, 'channel'),
      available: boolean(m, 'available'),
      platformProductId: optionalText(m, 'platformProductId'),
      regularPlatformProductId: optionalText(m, 'regularPlatformProductId'),
      discountMembershipLevel: optionalText(m, 'discountMembershipLevel'),
      packDiscountBps: optionalInteger(m, 'packDiscountBps'),
      unavailableReason: optionalText(m, 'unavailableReason'),
    );
  }

  static MembershipCurrent membership(Object? value) {
    final m = object(value);
    return MembershipCurrent(
      level: oneOf(m, 'level', membershipLevels),
      entitlementVersionId: optionalInteger(m, 'entitlementVersionId'),
      currentTermId: optionalInteger(m, 'currentTermId'),
      currentMonths: optionalInteger(m, 'currentMonths'),
      expiresAt: optionalDate(m, 'expiresAt'),
      nextGrantAt: optionalDate(m, 'nextGrantAt'),
      pendingOrderNo: optionalText(m, 'pendingOrderNo'),
      benefits: m['benefits'] == null
          ? null
          : Map.unmodifiable(object(m['benefits'])),
      terms: List.unmodifiable(
        (m['terms'] == null && m['ruleVersion'] == 'PAUSE_QUEUE_V1'
                ? <Object?>[]
                : list(m, 'terms'))
            .map(term),
      ),
      ruleVersion: optionalText(m, 'ruleVersion'),
      membershipVersion: m['membershipVersion'] == null
          ? null
          : MembershipV2Dto.id(m, 'membershipVersion'),
      observedAt: optionalDate(m, 'observedAt'),
      activeEntitlement: m['activeEntitlement'] == null
          ? null
          : MembershipV2Dto.item(m['activeEntitlement']),
      retainedEntitlements: MembershipV2Dto.items(
        m['retainedEntitlements'] ?? [],
      ),
      queuedEntitlements: MembershipV2Dto.items(m['queuedEntitlements'] ?? []),
    );
  }

  static MembershipTerm term(Object? value) {
    final m = object(value);
    return MembershipTerm(
      id: integer(m, 'id'),
      sourceOrderNo: text(m, 'sourceOrderNo'),
      level: oneOf(m, 'level', membershipLevels),
      termKind: text(m, 'termKind'),
      startsAt: date(m, 'startsAt'),
      endsAt: date(m, 'endsAt'),
      status: text(m, 'status'),
    );
  }

  static CommerceQuote quote(Object? value) {
    final m = object(value);
    final preview = m['membershipPreview'] == null
        ? null
        : MembershipV2Dto.preview(m['membershipPreview']);
    if (preview != null &&
        (preview.purchaseType != text(m, 'purchaseType') ||
            integer(m, 'conversionSeconds') != 0)) {
      throw const FormatException('Contradictory membership preview');
    }
    return CommerceQuote(
      quoteId: text(m, 'quoteId'),
      configVersionId: integer(m, 'configVersionId'),
      productId: text(m, 'productId'),
      purchaseType: oneOf(m, 'purchaseType', [
        'NEW',
        'RENEW',
        'UPGRADE',
        'LOWER_QUEUED',
        'PACK',
      ]),
      cashAmountFen: integer(m, 'cashAmountFen'),
      currency: text(m, 'currency'),
      conversionSeconds: integer(m, 'conversionSeconds'),
      estimatedExpiresAt: optionalDate(m, 'estimatedExpiresAt'),
      membershipPreview: preview,
      expiresAt: date(m, 'expiresAt'),
    );
  }

  static CommerceOrder order(Object? value) {
    final m = object(value);
    final paidFen = integer(m, 'cashPaidFen');
    final invoiceAvailableFen = optionalInteger(m, 'invoiceAvailableFen');
    if (invoiceAvailableFen != null && invoiceAvailableFen > paidFen) {
      throw const FormatException('Invalid invoiceAvailableFen');
    }
    final receipt = PlatformPaymentAmount.parse(
      optionalText(m, 'platformPaidCurrency'),
      optionalText(m, 'platformPaidAmountMilliunits'),
    );
    final membershipMonths = optionalInteger(m, 'membershipMonths');
    if (membershipMonths != null &&
        !const {1, 3, 12}.contains(membershipMonths)) {
      throw const FormatException('Invalid membershipMonths');
    }
    final result = CommerceOrder(
      orderNo: text(m, 'orderNo'),
      quoteId: optionalText(m, 'quoteId'),
      productType: oneOf(m, 'productType', ['MEMBERSHIP', 'POINTS_PACK']),
      productName: text(m, 'productName'),
      paymentState: text(m, 'paymentState'),
      fulfillmentState: text(m, 'fulfillmentState'),
      cashAmountFen: integer(m, 'cashAmountFen'),
      cashPaidFen: paidFen,
      invoiceAvailableFen: invoiceAvailableFen,
      platformPaidCurrency: receipt?.currency,
      platformPaidAmountMilliunits: receipt?.milliunits,
      currency: text(m, 'currency'),
      channel: text(m, 'channel'),
      createdAt: date(m, 'createdAt'),
      paidAt: optionalDate(m, 'paidAt'),
      fulfilledAt: optionalDate(m, 'fulfilledAt'),
      effectiveAt: optionalDate(m, 'effectiveAt'),
      expiresAt: optionalDate(m, 'expiresAt'),
      rowVersion: integer(m, 'rowVersion'),
      safeErrorCode: optionalText(m, 'safeErrorCode'),
      recoveryRequired: boolean(m, 'recoveryRequired'),
      invoiceAllowed: boolean(m, 'invoiceAllowed'),
      membershipLevel: m['membershipLevel'] == null
          ? null
          : oneOf(m, 'membershipLevel', const ['BASIC', 'PLUS', 'PREMIUM']),
      membershipMonths: membershipMonths,
      platformProductId: optionalText(m, 'platformProductId'),
      membershipFulfillment: m['membershipFulfillment'] == null
          ? null
          : MembershipV2Dto.fulfillment(m['membershipFulfillment']),
    );
    if (text(m, 'appState') != result.appState.code) {
      throw const FormatException('Contradictory order projection');
    }
    return result;
  }

  static OrderPage orders(Object? value) {
    final m = object(value);
    return OrderPage(
      List.unmodifiable(list(m, 'items').map(order)),
      integer(m, 'page'),
      integer(m, 'totalPages'),
    );
  }

  static RecoveryPreview recovery(Object? value) {
    final m = object(value);
    final receipt = PlatformPaymentAmount.parse(
      optionalText(m, 'platformPaidCurrency'),
      optionalText(m, 'platformPaidAmountMilliunits'),
    );
    return RecoveryPreview(
      recoveryQuoteId: text(m, 'recoveryQuoteId'),
      proposalHash: text(m, 'proposalHash'),
      orderNo: text(m, 'orderNo'),
      cashPaidFen: integer(m, 'cashPaidFen'),
      platformPaidCurrency: receipt?.currency,
      platformPaidAmountMilliunits: receipt?.milliunits,
      referenceValueFen: optionalInteger(m, 'referenceValueFen'),
      targetLevel: oneOf(m, 'targetLevel', membershipLevels),
      pricingOrderNo: text(m, 'pricingOrderNo'),
      targetPriceFen: integer(m, 'targetPriceFen'),
      targetMonths: integer(m, 'targetMonths'),
      appendSeconds: integer(m, 'appendSeconds'),
      appendStartsAt: date(m, 'appendStartsAt'),
      estimatedExpiresAt: date(m, 'estimatedExpiresAt'),
      expiresAt: date(m, 'expiresAt'),
    );
  }

  static PaymentMaterial payment(Object? value) {
    final m = object(value);
    final p = object(m['parameters']);
    return PaymentMaterial(
      channel: text(m, 'channel'),
      orderNo: text(m, 'orderNo'),
      expiresAt: date(m, 'expiresAt'),
      parameters: Map.unmodifiable(
        p.map((key, value) => MapEntry(key, text(p, key))),
      ),
    );
  }
}
