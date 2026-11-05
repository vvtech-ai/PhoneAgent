import 'dart:convert';
import 'dart:typed_data';

const documentMaxBytes = 5 * 1024 * 1024;

class SelectedDocument {
  const SelectedDocument({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.read,
  });
  final String name, mimeType;
  final int size;
  final Future<Uint8List> Function() read;
  bool get supported =>
      const ['.docx', '.xlsx'].any(name.toLowerCase().endsWith);
}

class ParsedDocument {
  const ParsedDocument({
    required this.status,
    this.fileName = '',
    this.mimeType = '',
    this.content = '',
    this.charCount = 0,
    this.truncated = false,
    this.message = '',
  });
  final String status, fileName, mimeType, content, message;
  final int charCount;
  final bool truncated;
  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'mimeType': mimeType,
    'charCount': charCount,
    'truncated': truncated,
    'content': content,
  };
}

class DocumentTurn {
  DocumentTurn(this.batchId, List<ParsedDocument> documents)
    : documents = List.unmodifiable(documents) {
    if (batchId.isEmpty ||
        documents.isEmpty ||
        documents.any((d) => d.status != 'OK')) {
      throw const FormatException('Incomplete document batch');
    }
  }
  final String batchId;
  final List<ParsedDocument> documents;
  String get payload => jsonEncode({
    'schema': 'user_document_batch.v1',
    'documentBatchId': batchId,
    'documents': documents.map((d) => d.toJson()).toList(),
  });
  String get display => documents
      .map(
        (d) =>
            '${d.fileName.isEmpty ? '已上传文档' : d.fileName}\n${d.charCount} 字${d.truncated ? ' · 内容已截断' : ''}',
      )
      .join('\n\n');
}

abstract interface class DocumentPicker {
  Future<List<SelectedDocument>> pick();
}

abstract interface class DocumentParser {
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes);
}
