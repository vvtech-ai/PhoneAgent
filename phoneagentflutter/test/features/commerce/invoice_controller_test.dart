import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';

class _Repository implements InvoiceRepository {
  final ids = <String>[];
  bool fail = true;
  String status = 'INVOICING';
  Completer<CommerceInvoice?>? pending;
  @override
  Future<CommerceInvoice?> invoice(String orderNo) async => pending?.future;
  @override
  Future<CommerceInvoice> apply(
    String orderNo,
    Map<String, Object?> request,
  ) async {
    ids.add(request['requestId'] as String);
    if (fail) throw StateError('synthetic failure');
    return CommerceInvoice(
      invoiceNo: 'invoice-1',
      orderNo: 'order-1',
      status: status,
      cashAmountFen: 3000,
      titleMasked: '合*',
      availableFormats: [],
    );
  }
}

void main() {
  test(
    'trusted failed response preserves input and retry requires server order capability',
    () async {
      final repository = _Repository()
        ..fail = false
        ..status = 'FAILED';
      final controller = InvoiceController('order-1', repository);
      controller.change('title', '合成个人');
      controller.change('email', 'buyer@example.com');
      await controller.submit();
      expect(controller.draft.fields['title'], '合成个人');
      controller.retryDraft(invoiceAllowed: false);
      expect(controller.state.invoice?.status, 'FAILED');
      controller.retryDraft(invoiceAllowed: true);
      expect(controller.state.invoice, isNull);
      await controller.submit();
      expect(repository.ids[0], isNot(repository.ids[1]));
      controller.dispose();
    },
  );
  test(
    'failed invoice keeps input and request identity until input changes',
    () async {
      final repository = _Repository();
      final controller = InvoiceController('order-1', repository);
      controller.change('title', '合成个人');
      controller.change('email', 'buyer@example.com');
      await controller.submit();
      await controller.submit();
      expect(controller.draft.fields['title'], '合成个人');
      expect(repository.ids[0], repository.ids[1]);
      controller.change('title', '另一合成个人');
      await controller.submit();
      expect(repository.ids[2], isNot(repository.ids[1]));
      controller.dispose();
    },
  );
  test('account disposal clears draft and ignores old invoice query', () async {
    final repository = _Repository()..pending = Completer();
    final controller = InvoiceController('order-1', repository);
    controller.change('title', '合成个人');
    final pending = controller.refresh();
    controller.dispose();
    expect(controller.draft.fields['title'], isEmpty);
    repository.pending!.complete(null);
    await pending;
  });
}
