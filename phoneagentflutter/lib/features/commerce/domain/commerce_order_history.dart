import 'commerce_order.dart';

/// Optional filtered paging capability; existing repository callers stay valid.
abstract interface class CommerceOrderHistory {
  Future<OrderPage> orders(int page, {int size = 20, String? channel});
}
