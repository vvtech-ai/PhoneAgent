import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/order_invoice_statuses_provider.dart';
import 'commerce_orders_page.dart';
import 'invoice_route.dart';
import 'purchase_result_route.dart';

class CommerceOrdersRoute extends ConsumerWidget {
  const CommerceOrdersRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersControllerProvider);
    final controller = ref.read(ordersControllerProvider.notifier);
    final invoiceStatuses = {
      for (final order in state.items)
        if (order.paymentState == 'SUCCEEDED' && !order.unresolved)
          order.orderNo:
              ref
                  .watch(orderInvoiceStatusProvider(order.orderNo))
                  .valueOrNull ??
              'UNKNOWN',
    };
    Future<void> refresh() async {
      await controller.refresh();
      if (context.mounted) ref.invalidate(orderInvoiceStatusProvider);
    }

    return CommerceOrdersPage(
      state: state,
      invoiceStatuses: invoiceStatuses,
      onBack: () => Navigator.pop(context),
      onRefresh: refresh,
      onNext: controller.next,
      onOrder: (order) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => UncontrolledProviderScope(
              container: ProviderScope.containerOf(context),
              child: PurchaseResultRoute(orderNo: order.orderNo),
            ),
          ),
        );
        if (context.mounted) refresh();
      },
      onInvoice: (order) async {
        await showCommerceInvoice(context, order);
        if (context.mounted) refresh();
      },
    );
  }
}
