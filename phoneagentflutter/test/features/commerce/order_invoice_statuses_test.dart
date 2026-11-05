import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/order_invoice_statuses_provider.dart';
import 'package:phone_agent/features/commerce/domain/invoice.dart';

class _Invoices implements InvoiceRepository {
  final pending = <String, Completer<CommerceInvoice?>>{};
  final reads = <String>[];
  @override
  Future<CommerceInvoice?> invoice(String orderNo) {
    reads.add(orderNo);
    return (pending[orderNo] = Completer<CommerceInvoice?>()).future;
  }

  @override
  Future<CommerceInvoice> apply(String orderNo, Map<String, Object?> request) =>
      throw StateError('Display must not apply for an invoice');
}

void main() {
  test(
    'status reads are bounded and reject another order projection',
    () async {
      final repo = _Invoices();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          invoiceRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final futures = <Future<String>>[];
      for (final id in ['1', '2', '3', '4', '5']) {
        container.listen(orderInvoiceStatusProvider(id), (_, _) {});
        futures.add(container.read(orderInvoiceStatusProvider(id).future));
      }
      expect(repo.pending.keys, ['1', '2', '3', '4']);
      repo.pending['1']!.complete(
        const CommerceInvoice(
          invoiceNo: 'i',
          orderNo: '1',
          status: 'ISSUED',
          cashAmountFen: 100,
          titleMasked: '',
          availableFormats: [],
        ),
      );
      repo.pending['2']!.complete(
        const CommerceInvoice(
          invoiceNo: 'i',
          orderNo: 'wrong',
          status: 'ISSUED',
          cashAmountFen: 100,
          titleMasked: '',
          availableFormats: [],
        ),
      );
      repo.pending['3']!.completeError(StateError('network unavailable'));
      repo.pending['4']!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.pending.keys, ['1', '2', '3', '4', '5']);
      repo.pending['5']!.complete(null);
      expect(await Future.wait(futures), [
        'ISSUED',
        'UNKNOWN',
        'UNKNOWN',
        'NOT_APPLIED',
        'NOT_APPLIED',
      ]);
      // Appending a page preserves visible projections and reads only new rows.
      container.listen(orderInvoiceStatusProvider('6'), (_, _) {});
      expect(
        container.read(orderInvoiceStatusProvider('1')).valueOrNull,
        'ISSUED',
      );
      expect(repo.reads, ['1', '2', '3', '4', '5', '6']);
      repo.pending['6']!.complete(null);
      await container.read(orderInvoiceStatusProvider('6').future);
      container.invalidate(orderInvoiceStatusProvider('1'));
      final refreshed = container.read(orderInvoiceStatusProvider('1').future);
      expect(repo.reads.last, '1');
      repo.pending['1']!.complete(null);
      expect(await refreshed, 'NOT_APPLIED');
    },
  );
}
