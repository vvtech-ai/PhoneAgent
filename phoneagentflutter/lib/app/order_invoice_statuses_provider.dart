import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_providers.dart';
import 'commerce_providers.dart';

final _invoiceReadsProvider = Provider.autoDispose(
  (ref) => _InvoiceReadQueue(),
);

/// Keep each visible order independent, so pagination preserves existing states.
final orderInvoiceStatusProvider = FutureProvider.autoDispose
    .family<String, String>((ref, orderNo) async {
      ref.watch(loginEpochProvider);
      final repository = ref.watch(invoiceRepositoryProvider);
      final queue = ref.watch(_invoiceReadsProvider);
      var active = true;
      ref.onDispose(() => active = false);
      return queue.read(() async {
        if (!active) return 'UNKNOWN';
        try {
          final invoice = await repository.invoice(orderNo);
          return invoice == null
              ? 'NOT_APPLIED'
              : invoice.orderNo == orderNo
              ? invoice.status
              : 'UNKNOWN';
        } catch (_) {
          return 'UNKNOWN';
        }
      });
    });

/// Only limits concurrent read requests; never applies for an invoice.
class _InvoiceReadQueue {
  final _waiting = <void Function()>[];
  int _running = 0;

  Future<String> read(Future<String> Function() request) {
    final result = Completer<String>();
    Future<void> run() async {
      _running++;
      try {
        result.complete(await request());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _running--;
        if (_waiting.isNotEmpty) _waiting.removeAt(0)();
      }
    }

    if (_running < 4) {
      run();
    } else {
      _waiting.add(run);
    }
    return result.future;
  }
}
