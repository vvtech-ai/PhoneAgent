import 'commerce_order.dart';
import 'commerce_catalog.dart';
import 'commerce_repository.dart';
import 'payment_launcher.dart';

bool confirmsApplePrice(
  ProductOffer offer,
  PlatformProduct? fresh,
  PlatformProduct confirmed,
) =>
    fresh != null &&
    fresh.id == offer.platformProductId &&
    fresh.samePrice(confirmed) &&
    fresh.supports(offer.productType) &&
    fresh.price != null &&
    fresh.currencyCode != null;

/// Bind fresh payment material to the original order and accepted Apple price.
PaymentMaterial confirmedPaymentMaterial(
  CommerceOrder order,
  PaymentMaterial material,
  PlatformProduct? apple,
) {
  if (material.orderNo != order.orderNo || material.channel != order.channel) {
    throw const FormatException('Payment material mismatch');
  }
  if (order.channel != 'APPLE_IAP') return material;
  if (apple == null ||
      material.parameters['platformProductId'] != apple.id ||
      !apple.supports(order.productType) ||
      apple.price == null ||
      apple.currencyCode == null) {
    throw const CommerceFailure('APPLE_PRICE_CHANGED');
  }
  if (material.expiresAt.isBefore(DateTime.now())) {
    throw const CommerceFailure('PAYMENT_EXPIRED');
  }
  return PaymentMaterial(
    channel: material.channel,
    orderNo: material.orderNo,
    expiresAt: material.expiresAt,
    parameters: {
      ...material.parameters,
      'expectedPrice': apple.price!,
      'expectedCurrency': apple.currencyCode!,
      'expectedType': apple.productType!,
    },
  );
}
