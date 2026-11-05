export 'commerce_failure.dart';
import 'commerce_catalog.dart';
import 'commerce_order.dart';
import 'payment_launcher.dart';

abstract interface class CommerceRepository {
  Future<CommerceCatalog> catalog();
  Future<MembershipCurrent> membership();
  Future<CommerceQuote> quote(String productId, int configVersionId);
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  );
  Future<PaymentMaterial> payment(String orderNo);
  Future<CommerceOrder> order(String orderNo);
  Future<OrderPage> orders(int page);
  Future<CommerceOrder> closeOrder(String orderNo, String requestId);
  Future<CommerceOrder> verifyApple(NativePaymentResult result);
  Future<RecoveryPreview> recoveryPreview(String orderNo);
  Future<CommerceOrder> recoveryConfirm(
    RecoveryPreview preview,
    String requestId,
  );
}
