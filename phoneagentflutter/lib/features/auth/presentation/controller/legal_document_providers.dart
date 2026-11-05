import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/method_channel_legal_document_port.dart';
import '../../domain/legal_document_port.dart';

final legalDocumentPortProvider = Provider<LegalDocumentPort>(
  (_) => const MethodChannelLegalDocumentPort(),
);
