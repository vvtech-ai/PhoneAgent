enum TaskArtifactKind { template, batchCsv }

class TaskArtifact {
  const TaskArtifact({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.status,
    this.sourceBatchId = '',
    this.itemCount,
  });
  final String id, fileName, mimeType, status, sourceBatchId;
  final TaskArtifactKind kind;
  final int? itemCount;
  bool get ready => status == 'READY';
  static bool validId(String id) =>
      RegExp(r'^skill-template:[A-Za-z0-9_-]+:v1$').hasMatch(id) ||
      RegExp(
        r'^batch-receipt-csv\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
      ).hasMatch(id);
  static TaskArtifact? parse(Object? raw) {
    if (raw is! Map) return null;
    String text(String key) =>
        raw[key] is String ? (raw[key] as String).trim() : '';
    final id = text('artifactId'),
        kind = text('kind'),
        name = text('fileName'),
        mime = text('mimeType');
    final template =
        kind == 'SKILL_TEMPLATE' && id.startsWith('skill-template:');
    final csv =
        kind == 'BATCH_RECEIPT_CSV' && id.startsWith('batch-receipt-csv.');
    if (!validId(id) ||
        (!template && !csv) ||
        name.isEmpty ||
        name.length > 180 ||
        RegExp(r'[\\/\x00-\x1f]').hasMatch(name) ||
        name == '.' ||
        name == '..' ||
        (template
            ? !name.toLowerCase().endsWith('.docx')
            : !name.toLowerCase().endsWith('.csv')) ||
        (template
            ? mime !=
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            : mime.split(';').first.trim().toLowerCase() != 'text/csv')) {
      return null;
    }
    final count = raw['itemCount'];
    return TaskArtifact(
      id: id,
      kind: template ? TaskArtifactKind.template : TaskArtifactKind.batchCsv,
      fileName: name,
      mimeType: mime,
      status: text('status'),
      sourceBatchId: text('sourceBatchId'),
      itemCount: count is int && count >= 0 ? count : null,
    );
  }
}
