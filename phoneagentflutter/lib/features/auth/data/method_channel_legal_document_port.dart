import 'package:flutter/services.dart';

import '../domain/legal_document_port.dart';

final class MethodChannelLegalDocumentPort implements LegalDocumentPort {
  const MethodChannelLegalDocumentPort();
  static const _channel = MethodChannel('phone_agent/legal_documents');

  @override
  Future<void> open(LegalDocument document) =>
      _channel.invokeMethod<void>('open', document.name);
}
