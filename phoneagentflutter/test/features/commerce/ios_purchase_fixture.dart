import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

const appleOffer = ProductOffer(
  productId: 'm1',
  name: '合成会员',
  productType: 'MEMBERSHIP',
  level: 'BASIC',
  months: 1,
  cashAmountFen: 3000,
  basePoints: 0,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  available: true,
  platformProductId: 'synthetic-product',
);
const appleProduct = PlatformProduct(
  'synthetic-product',
  '¥30.00',
  price: '30',
  currencyCode: 'CNY',
  productType: 'nonRenewable',
);

const pack = ProductOffer(
  productId: 'p1',
  name: '合成积分',
  productType: 'POINTS_PACK',
  level: null,
  months: null,
  cashAmountFen: 600,
  basePoints: 600,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  available: true,
  platformProductId: 'pack-sku',
);

CommerceOrder appleOrder({
  String payment = 'SUCCEEDED',
  String fulfillment = 'PROCESSING',
}) => CommerceOrder(
  orderNo: 'order-1',
  quoteId: 'quote-1',
  productType: 'POINTS_PACK',
  productName: '测试积分',
  paymentState: payment,
  fulfillmentState: fulfillment,
  cashAmountFen: 3000,
  cashPaidFen: 3000,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  createdAt: DateTime(2026),
  rowVersion: 1,
);
