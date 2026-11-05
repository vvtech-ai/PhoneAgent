import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/commerce_repository.dart';
import '../domain/invoice.dart';
import 'api_commerce_repository.dart';
import 'commerce_dto.dart';

class ApiInvoiceRepository implements InvoiceRepository {
  const ApiInvoiceRepository(this.api);
  final AccountApi api;
  String _path(String orderNo) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(orderNo)) {
      throw const FormatException('Invalid order');
    }
    return 'api/commerce/orders/$orderNo/invoice';
  }

  static CommerceInvoice parse(Object? value) {
    final m = CommerceDto.object(value);
    final formats = CommerceDto.list(m, 'availableFormats');
    if (formats.any((f) => !const {'PDF', 'OFD', 'XML'}.contains(f))) {
      throw const FormatException('Invalid invoice format');
    }
    return CommerceInvoice(
      invoiceNo: CommerceDto.text(m, 'invoiceNo'),
      orderNo: CommerceDto.text(m, 'orderNo'),
      status: CommerceDto.oneOf(m, 'status', ['INVOICING', 'ISSUED', 'FAILED']),
      cashAmountFen: CommerceDto.integer(m, 'cashAmountFen'),
      titleMasked: CommerceDto.text(m, 'titleMasked'),
      availableFormats: List.unmodifiable(formats.cast<String>()),
      safeErrorCode: CommerceDto.optionalText(m, 'safeErrorCode'),
    );
  }

  @override
  Future<CommerceInvoice?> invoice(String orderNo) async {
    final value = await api.request(_path(orderNo));
    if (value == null) return null;
    final m = CommerceDto.object(value);
    if (m['status'] == 'NOT_APPLIED') {
      if (m['invoiceNo'] != null ||
          CommerceDto.text(m, 'orderNo') != orderNo ||
          CommerceDto.integer(m, 'cashAmountFen') != 0 ||
          CommerceDto.list(m, 'availableFormats').isNotEmpty) {
        throw const FormatException('Contradictory unapplied invoice');
      }
      return null;
    }
    return parse(value);
  }

  @override
  Future<CommerceInvoice> apply(
    String orderNo,
    Map<String, Object?> request,
  ) async {
    try {
      return parse(
        await api.request(
          _path(orderNo),
          method: 'POST',
          body: request,
          idempotencyKey: request['requestId'] as String,
          exposedCodes: ApiCommerceRepository.errorCodes,
          exposedDataCodes: ApiCommerceRepository.errorCodes,
        ),
      );
    } on ApiCodeFailure catch (e) {
      throw CommerceFailure(e.code);
    }
  }
}
