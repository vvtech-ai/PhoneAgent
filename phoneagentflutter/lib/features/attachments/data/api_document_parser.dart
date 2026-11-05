import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/document_import.dart';

class ApiDocumentParser implements DocumentParser {
  ApiDocumentParser(this.api, {this.agentRequest = false});
  final AccountApi api;
  final bool agentRequest;
  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    final supported = agentRequest
        ? const [
            'md',
            'markdown',
            'txt',
            'docx',
            'xlsx',
          ].contains(file.name.toLowerCase().split('.').last)
        : file.supported;
    if (bytes.length > documentMaxBytes || !supported) {
      throw const FormatException('Invalid selected document');
    }
    final raw = await api.request(
      'api/documents/parse',
      method: 'POST',
      body: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: DioMediaType.parse(file.mimeType),
        ),
      }),
    );
    if (raw is! Map ||
        raw['status'] is! String ||
        (raw['status'] as String).isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    String field(String key) {
      final value = raw[key];
      if (value != null && value is! String) throw ApiFailure.invalidResponse;
      return value as String? ?? '';
    }

    final count = raw['charCount'] ?? 0, truncated = raw['truncated'] ?? false;
    if (count is! int || count < 0 || truncated is! bool) {
      throw ApiFailure.invalidResponse;
    }
    return ParsedDocument(
      status: raw['status'] as String,
      fileName: field('fileName'),
      mimeType: field('mimeType'),
      content: field('content'),
      charCount: count,
      truncated: truncated,
      message: field('message'),
    );
  }
}
