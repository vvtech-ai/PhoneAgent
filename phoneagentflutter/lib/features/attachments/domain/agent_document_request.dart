import 'document_import.dart';

const agentDocumentMimeTypes = [
  'text/plain',
  'text/markdown',
  'text/*',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
];

class AgentDocumentRequest {
  const AgentDocumentRequest({
    this.title = '上传文件',
    this.reason = '',
    this.mimeTypes = agentDocumentMimeTypes,
    this.maxBytes = documentMaxBytes,
  });
  final String title, reason;
  final List<String> mimeTypes;
  final int maxBytes;

  factory AgentDocumentRequest.parse(Map<String, Object?> payload) {
    final nested = payload['documentImportRequest'];
    final data = nested is Map<String, Object?> ? nested : payload;
    String field(String key) => data[key] is String ? data[key] as String : '';
    final raw = data['acceptedMimeTypes'];
    final accepted = raw is List
        ? raw
              .whereType<String>()
              .map((s) => s.trim())
              .where(agentDocumentMimeTypes.contains)
              .toSet()
              .toList()
        : <String>[];
    final limit = data['maxBytes'];
    if (limit != null && (limit is! int || limit <= 0)) {
      throw const FormatException('Invalid document size limit');
    }
    return AgentDocumentRequest(
      title: field('title').trim().isEmpty ? '上传文件' : field('title'),
      reason: field('reason'),
      mimeTypes: accepted.isEmpty ? agentDocumentMimeTypes : accepted,
      maxBytes: limit is int && limit < documentMaxBytes
          ? limit
          : documentMaxBytes,
    );
  }
}

abstract interface class AgentDocumentPicker {
  Future<SelectedDocument?> pick(AgentDocumentRequest request);
}

abstract interface class AgentDocumentSource {
  Future<ParsedDocument?> resolve(
    AgentDocumentRequest request, {
    required bool Function() isCurrent,
  });
}

String agentDocumentEcho(ParsedDocument result) => switch (result.status) {
  'OK' => '已上传并解析：${result.fileName.isEmpty ? '文档' : result.fileName}',
  'USER_CANCELLED' => '已取消文件选择',
  'UNSUPPORTED_TYPE' => '文件类型暂不支持',
  'FILE_TOO_LARGE' => '文件过大，无法解析',
  _ => '文件解析失败',
};
