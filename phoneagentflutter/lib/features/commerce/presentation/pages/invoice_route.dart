import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/commerce_providers.dart';
import '../../domain/commerce_order.dart';
import '../widgets/invoice_sheet.dart';
import '../invoice_availability_notice.dart';

Future<void> showCommerceInvoice(BuildContext context, CommerceOrder order) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _InvoiceRoute(order),
        ),
      ),
    );

class _InvoiceRoute extends ConsumerWidget {
  const _InvoiceRoute(this.order);
  final CommerceOrder order;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(invoiceControllerProvider(order.orderNo));
    final controller = ref.read(
      invoiceControllerProvider(order.orderNo).notifier,
    );
    return InvoiceSheet(
      cashAmountFen: order.invoiceAvailableFen ?? order.cashPaidFen,
      state: state,
      draft: controller.draft,
      allowApply: order.invoiceAllowed,
      unavailableNotice: invoiceAvailabilityNotice(order),
      supportEmail: ref.watch(catalogControllerProvider).catalog?.supportEmail,
      onClose: () => Navigator.pop(context),
      onTitle: controller.title,
      onType: controller.type,
      onChange: controller.change,
      onSubmit: order.invoiceAllowed ? controller.submit : () {},
      onRefresh: controller.refresh,
      onRetry: () =>
          controller.retryDraft(invoiceAllowed: order.invoiceAllowed),
    );
  }
}
