class CommerceInvoice {
  const CommerceInvoice({
    required this.invoiceNo,
    required this.orderNo,
    required this.status,
    required this.cashAmountFen,
    required this.titleMasked,
    required this.availableFormats,
    this.safeErrorCode,
  });
  final String invoiceNo, orderNo, status, titleMasked;
  final String? safeErrorCode;
  final int cashAmountFen;
  final List<String> availableFormats;
}

class InvoiceDraft {
  String titleType = 'PERSONAL', invoiceType = 'ORDINARY';
  static const keys = [
    'title',
    'taxNumber',
    'email',
    'bankName',
    'bankAccount',
    'companyAddress',
    'companyPhone',
  ];
  final _drafts = <String, Map<String, String>>{};
  Map<String, String> get fields => _drafts.putIfAbsent(
    '$titleType-$invoiceType',
    () => {for (final key in keys) key: ''},
  );
  void selectTitle(String value) {
    if (!const {'PERSONAL', 'COMPANY'}.contains(value)) return;
    if (value == 'PERSONAL') {
      _drafts.removeWhere((key, _) => key.startsWith('COMPANY-'));
      invoiceType = 'ORDINARY';
    }
    titleType = value;
  }

  void selectType(String value) {
    if (!const {'ORDINARY', 'SPECIAL'}.contains(value)) return;
    invoiceType = titleType == 'PERSONAL' ? 'ORDINARY' : value;
  }

  void set(String key, String value) {
    if (keys.contains(key)) fields[key] = value;
  }

  String get validation {
    if (fields['title']!.trim().isEmpty) return '请填写发票抬头';
    if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(fields['email']!.trim())) {
      return '请填写有效邮箱';
    }
    if (titleType == 'COMPANY' &&
        !RegExp(
          r'^[A-Za-z0-9]{15,20}$',
        ).hasMatch(fields['taxNumber']!.trim())) {
      return '请填写有效企业税号';
    }
    if (invoiceType == 'SPECIAL' &&
        [
          'bankName',
          'bankAccount',
          'companyAddress',
          'companyPhone',
        ].any((key) => fields[key]!.trim().isEmpty)) {
      return '请完整填写企业地址、电话及开户资料';
    }
    return '';
  }

  Map<String, Object?> request(String requestId) => {
    'requestId': requestId,
    'titleType': titleType,
    'invoiceType': invoiceType,
    for (final key in keys) key: fields[key]!.trim(),
  };
  void clear() {
    _drafts.clear();
    titleType = 'PERSONAL';
    invoiceType = 'ORDINARY';
  }
}

abstract interface class InvoiceRepository {
  Future<CommerceInvoice?> invoice(String orderNo);
  Future<CommerceInvoice> apply(String orderNo, Map<String, Object?> request);
}
