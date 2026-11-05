import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invoice.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/request_identity.dart';

class InvoiceState {
  const InvoiceState({
    this.invoice,
    this.busy = false,
    this.error = '',
    this.revision = 0,
  });
  final CommerceInvoice? invoice;
  final bool busy;
  final String error;
  final int revision;
}

class InvoiceController extends StateNotifier<InvoiceState> {
  InvoiceController(this.orderNo, this.repository)
    : super(const InvoiceState());
  final String orderNo;
  final InvoiceRepository repository;
  final draft = InvoiceDraft();
  void retryDraft({required bool invoiceAllowed}) {
    if (!mounted ||
        state.busy ||
        !invoiceAllowed ||
        state.invoice?.status != 'FAILED') {
      return;
    }
    _requestId = null;
    state = InvoiceState(revision: state.revision + 1);
  }

  String? _requestId;
  void _edited() {
    _requestId = null;
    state = InvoiceState(invoice: state.invoice, revision: state.revision + 1);
  }

  void change(String field, String value) {
    if (!mounted || state.busy) return;
    draft.set(field, value);
    _edited();
  }

  void title(String value) {
    if (!mounted || state.busy) return;
    draft.selectTitle(value);
    _edited();
  }

  void type(String value) {
    if (!mounted || state.busy) return;
    draft.selectType(value);
    _edited();
  }

  String _error(Object e) => e is CommerceFailure ? e.message : '发票操作失败，请重试';
  Future<void> refresh() async {
    if (!mounted || state.busy) return;
    state = InvoiceState(
      invoice: state.invoice,
      busy: true,
      revision: state.revision,
    );
    try {
      final invoice = await repository.invoice(orderNo);
      if (!mounted) return;
      if (invoice != null && invoice.orderNo != orderNo) {
        throw const FormatException('Invoice mismatch');
      }
      state = InvoiceState(invoice: invoice, revision: state.revision);
    } catch (e) {
      if (mounted) {
        state = InvoiceState(
          invoice: state.invoice,
          error: _error(e),
          revision: state.revision,
        );
      }
    }
  }

  Future<void> submit() async {
    if (!mounted || state.busy || state.invoice != null) return;
    if (draft.validation.isNotEmpty) {
      state = InvoiceState(error: draft.validation, revision: state.revision);
      return;
    }
    final request = draft.request(_requestId ??= commerceRequestId());
    state = InvoiceState(busy: true, revision: state.revision);
    try {
      final invoice = await repository.apply(orderNo, request);
      if (!mounted) return;
      if (invoice.orderNo != orderNo) {
        throw const FormatException('Invoice mismatch');
      }
      if (invoice.status != 'FAILED') draft.clear();
      state = InvoiceState(invoice: invoice, revision: state.revision + 1);
    } catch (e) {
      if (mounted) {
        state = InvoiceState(error: _error(e), revision: state.revision);
      }
    }
  }

  @override
  void dispose() {
    draft.clear();
    super.dispose();
  }
}
