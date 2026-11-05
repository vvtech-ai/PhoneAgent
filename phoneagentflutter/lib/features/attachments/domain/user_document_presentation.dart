import 'dart:convert';
import 'document_import.dart';

class UserDocumentFile {
  const UserDocumentFile(
    this.name, {
    this.mimeType = '',
    this.charCount = 0,
    this.truncated = false,
  });
  final String name, mimeType;
  final int charCount;
  final bool truncated;
  String get metadata => [
    if (name.toLowerCase().endsWith('.docx'))
      'Word 文档'
    else if (name.toLowerCase().endsWith('.xlsx'))
      'Excel 工作簿'
    else if (mimeType.isNotEmpty)
      mimeType
    else
      '任务文档',
    if (charCount > 0) '已解析 $charCount 字',
    if (truncated) '内容已截断',
  ].join(' · ');
  factory UserDocumentFile.parsed(ParsedDocument document) => UserDocumentFile(
    document.fileName.isEmpty ? '已上传文档' : document.fileName,
    mimeType: document.mimeType,
    charCount: document.charCount,
    truncated: document.truncated,
  );
}

class UserDocumentPresentation {
  UserDocumentPresentation(this.batchId, List<UserDocumentFile> files)
    : files = List.unmodifiable(files);
  final String batchId;
  final List<UserDocumentFile> files;

  factory UserDocumentPresentation.turn(DocumentTurn turn) =>
      UserDocumentPresentation(
        turn.batchId,
        turn.documents.map(UserDocumentFile.parsed).toList(),
      );

  static UserDocumentPresentation? fromTurnText(String text) {
    try {
      final payload = jsonDecode(text);
      if (payload is! Map ||
          payload['schema'] != 'user_document_batch.v1' ||
          payload['documentBatchId'] is! String ||
          (payload['documentBatchId'] as String).isEmpty ||
          payload['documents'] is! List) {
        return null;
      }
      final files = <UserDocumentFile>[];
      for (final value in payload['documents'] as List) {
        if (value is! Map ||
            value['fileName'] is! String ||
            (value['fileName'] as String).trim().isEmpty) {
          return null;
        }
        final count = value['charCount'];
        if (count != null && (count is! int || count < 0)) return null;
        if (value['mimeType'] != null && value['mimeType'] is! String) {
          return null;
        }
        if (value['truncated'] != null && value['truncated'] is! bool) {
          return null;
        }
        files.add(
          UserDocumentFile(
            value['fileName'] as String,
            mimeType: value['mimeType'] as String? ?? '',
            charCount: count as int? ?? 0,
            truncated: value['truncated'] == true,
          ),
        );
      }
      return files.isEmpty
          ? null
          : UserDocumentPresentation(
              payload['documentBatchId'] as String,
              files,
            );
    } on FormatException {
      return null;
    }
  }
}
