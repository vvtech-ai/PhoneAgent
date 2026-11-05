import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';

class OrdersState {
  const OrdersState({
    this.items = const [],
    this.loading = false,
    this.hasNext = false,
    this.error = '',
  });
  final List<CommerceOrder> items;
  final bool loading, hasNext;
  final String error;
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController(this.repository) : super(const OrdersState());
  final CommerceRepository repository;
  int _page = -1, _revision = 0;
  Future<void> refresh() async {
    final revision = ++_revision;
    state = OrdersState(items: state.items, loading: true);
    await _read(0, revision);
  }

  Future<void> next() async {
    if (!mounted || state.loading || !state.hasNext) return;
    state = OrdersState(items: state.items, loading: true, hasNext: true);
    await _read(_page + 1, ++_revision);
  }

  Future<void> _read(int page, int revision) async {
    try {
      final result = await repository.orders(page);
      if (!mounted || revision != _revision) return;
      if (result.page != page) {
        throw const FormatException('Unexpected order page');
      }
      final items = {
        if (page > 0)
          for (final order in state.items) order.orderNo: order,
      };
      for (final order in result.items) {
        items[order.orderNo] = order;
      }
      _page = page;
      state = OrdersState(
        items: List.unmodifiable(items.values),
        hasNext: result.hasNext,
      );
    } catch (e) {
      if (mounted && revision == _revision) {
        state = OrdersState(
          items: state.items,
          hasNext: state.hasNext,
          error: e is CommerceFailure ? e.message : '订单加载失败，请重试',
        );
      }
    }
  }
}
