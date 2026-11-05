import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

List<Override> commercePreviewOverrides({CommerceRepository? repository}) => [
  commerceRepositoryProvider.overrideWithValue(
    repository ?? const _PreviewCommerce(),
  ),
  paymentLauncherProvider.overrideWithValue(const _NoPayment()),
];

/// Explicit MOCK-only read ports. No payable products or success fabrication.
class _PreviewCommerce implements CommerceRepository {
  const _PreviewCommerce();
  @override
  Future<CommerceCatalog> catalog() async => const CommerceCatalog(
    configVersionId: 0,
    revisionNo: 0,
    agreementVersion: '',
    agreementUrl: '',
    supportEmail: '',
    products: [],
  );
  @override
  Future<MembershipCurrent> membership() async => const MembershipCurrent(
    level: 'FREE',
    entitlementVersionId: null,
    benefits: null,
    terms: [],
  );
  @override
  Future<OrderPage> orders(int page) async => OrderPage([], page, 0);
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) async =>
      throw const CommerceFailure('PRODUCT_UNAVAILABLE');
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async => throw const CommerceFailure('PRODUCT_UNAVAILABLE');
  @override
  Future<PaymentMaterial> payment(String orderNo) async =>
      throw const PaymentUnavailable();
  @override
  Future<CommerceOrder> order(String orderNo) async =>
      throw const CommerceFailure('PRODUCT_UNAVAILABLE');
  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) async =>
      throw const CommerceFailure('PRODUCT_UNAVAILABLE');
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async =>
      throw const PaymentUnavailable();
  @override
  Future<RecoveryPreview> recoveryPreview(String orderNo) async =>
      throw const CommerceFailure('PRODUCT_UNAVAILABLE');
  @override
  Future<CommerceOrder> recoveryConfirm(
    RecoveryPreview preview,
    String requestId,
  ) async => throw const CommerceFailure('PRODUCT_UNAVAILABLE');
}

class _NoPayment implements PaymentLauncher {
  const _NoPayment();
  @override
  Future<bool> available() async => false;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {};
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async =>
      throw const PaymentUnavailable();
  @override
  Future<List<NativePaymentResult>> restore() async => [];
  @override
  Future<void> acknowledge(NativePaymentResult result) async =>
      throw const PaymentUnavailable();
}
