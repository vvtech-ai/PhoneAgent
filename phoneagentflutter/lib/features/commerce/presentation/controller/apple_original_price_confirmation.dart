import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';

/// Read the original locked SKU without preparing or occupying a payment attempt.
Future<PlatformProduct?> confirmOriginalApplePrice({
  required CommerceOrder order,
  required CommerceRepository repository,
  required PaymentLauncher launcher,
  required bool Function() isCurrent,
  required Future<bool> Function(PlatformProduct)? confirm,
}) async {
  if (confirm == null || !isCurrent()) return null;
  final original = await repository.order(order.orderNo);
  if (!isCurrent()) return null;
  final sku = original.platformProductId;
  if (original.orderNo != order.orderNo ||
      original.channel != 'APPLE_IAP' ||
      original.productType != order.productType ||
      original.paymentState != 'PENDING' ||
      original.fulfillmentState != 'NOT_STARTED' ||
      original.cashPaidFen != 0 ||
      sku == null ||
      sku.isEmpty) {
    throw const CommerceFailure('APPLE_PRICE_CHANGED');
  }
  final product = (await launcher.products({sku}))[sku];
  if (!isCurrent()) return null;
  if (product == null ||
      product.id != sku ||
      product.displayPrice.trim().isEmpty ||
      product.price == null ||
      product.currencyCode == null ||
      !product.supports(order.productType)) {
    throw const CommerceFailure('APPLE_PRICE_CHANGED');
  }
  return await confirm(product) && isCurrent() ? product : null;
}
