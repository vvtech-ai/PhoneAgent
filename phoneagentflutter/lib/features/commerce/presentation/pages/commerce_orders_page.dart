import 'package:flutter/material.dart';
import '../order_payment_amount.dart';
import '../../domain/commerce_order.dart';
import '../controller/orders_controller.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/commerce_order_action.dart';
import '../widgets/commerce_order_display.dart';
import '../widgets/commerce_empty_orders.dart';

class CommerceOrdersPage extends StatefulWidget {
  const CommerceOrdersPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRefresh,
    required this.onNext,
    required this.onOrder,
    required this.onInvoice,
    this.invoiceStatuses = const {},
  });
  final OrdersState state;
  final Map<String, String> invoiceStatuses;
  final VoidCallback onBack, onNext;
  final Future<void> Function() onRefresh;
  final ValueChanged<CommerceOrder> onOrder, onInvoice;
  @override
  State<CommerceOrdersPage> createState() => _CommerceOrdersPageState();
}

class _CommerceOrdersPageState extends State<CommerceOrdersPage> {
  final _scroll = ScrollController();
  static const _columnWidths = [113.0, 78.0, 72.0, 90.0, 105.0];
  double get _tableScale => MediaQuery.textScalerOf(context).scale(11) / 11;
  double get _tableWidth =>
      _columnWidths.fold<double>(0, (sum, width) => sum + width * _tableScale) +
      20;
  double _rowHeight({bool header = false}) =>
      (MediaQuery.textScalerOf(context).scale(11) * (header ? 1.5 : 3) + 16)
          .clamp(header ? 38.0 : 58.0, double.infinity);
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _cells(List<String> cells, {bool header = false}) => SizedBox(
    height: _rowHeight(header: header),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: _columnWidths[i] * _tableScale,
              child: Text(
                cells[i],
                maxLines: header ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: header || i == 0 || i == 2
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: header
                      ? const Color(0xFF747982)
                      : const Color(0xFF17191D),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  void _move(double amount) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (_scroll.offset + amount).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return CommerceScaffold(
      title: '订单与发票',
      onBack: widget.onBack,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (state.items.isNotEmpty)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '左右滑动查看支付渠道与状态',
                      style: TextStyle(fontSize: 10, color: Color(0xFF92969E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '向左滚动',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E5E9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: () => _move(-160),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  IconButton(
                    tooltip: '向右滚动',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E5E9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: () => _move(160),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            if (state.items.isEmpty && !state.loading && state.error.isEmpty)
              const CommerceEmptyOrders(),
            if (state.items.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Material(
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _tableWidth,
                            child: Column(
                              children: [
                                Container(
                                  color: const Color(0xFFF0F2F5),
                                  child: _cells([
                                    '类型',
                                    '日期',
                                    '金额',
                                    '支付渠道',
                                    '状态',
                                  ], header: true),
                                ),
                                for (final order in state.items)
                                  InkWell(
                                    onTap: () => widget.onOrder(order),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Color(0xFFEEF0F3),
                                          ),
                                        ),
                                      ),
                                      child: _cells([
                                        orderProductLabel(order),
                                        commerceDate(order.createdAt),
                                        orderPaymentAmount(order),
                                        orderChannelLabel(order.channel),
                                        orderListStateLabel(order),
                                      ]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 72 * _tableScale.clamp(1, 1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 10,
                              offset: Offset(-4, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: _rowHeight(header: true),
                              color: const Color(0xFFF0F2F5),
                              alignment: Alignment.center,
                              child: const Text(
                                '操作',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF747982),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            for (final order in state.items)
                              SizedBox(
                                height: _rowHeight(),
                                child: CommerceOrderAction(
                                  order: order,
                                  invoiceStatus:
                                      widget.invoiceStatuses[order.orderNo],
                                  onOrder: () => widget.onOrder(order),
                                  onInvoice: () => widget.onInvoice(order),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error.isNotEmpty)
              Column(
                children: [
                  Text(state.error),
                  TextButton(
                    onPressed: widget.onRefresh,
                    child: const Text('重试'),
                  ),
                ],
              ),
            if (state.hasNext)
              TextButton(
                onPressed: state.loading ? null : widget.onNext,
                child: const Text('加载更多'),
              ),
          ],
        ),
      ),
    );
  }
}
