import 'dart:convert';
import 'call_confirmation.dart';

enum BatchConfirmationDecision {
  pending('等待确认'),
  confirmed('已确认'),
  revisionRequested('待修改'),
  cancelled('已取消');

  const BatchConfirmationDecision(this.label);
  final String label;
  static BatchConfirmationDecision fromWire(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'CONFIRMED' => confirmed,
        'REVISION_REQUESTED' => revisionRequested,
        'CANCELLED' => cancelled,
        _ => pending,
      };
}

class BatchConfirmationSection {
  const BatchConfirmationSection(this.title, this.rows);
  final String title;
  final List<ConfirmationRow> rows;
}

class BatchConfirmationRecipient {
  const BatchConfirmationRecipient({
    required this.id,
    required this.name,
    required this.phone,
    required this.salutation,
    required this.status,
    required this.detail,
  });
  final String id, name, phone, salutation, status, detail;
  String get displayName => name.trim().isNotEmpty
      ? name.trim()
      : phone.trim().isNotEmpty
      ? phone.trim()
      : '未命名联系人';
  bool get runnable =>
      phone.trim().isNotEmpty &&
      !const {
        'INVALID',
        'MISSING',
        'SKIP',
        'BLOCKED',
        'NOT_EXECUTABLE',
        '暂不',
        '缺少',
        '异常',
      }.any(status.trim().toUpperCase().contains);
}

class BatchConfirmation {
  const BatchConfirmation({
    required this.snapshotId,
    required this.version,
    required this.title,
    required this.sections,
    required this.recipients,
    required this.issues,
    required this.rules,
    required this.assistantText,
    this.summary,
    this.decision = BatchConfirmationDecision.pending,
  });
  final String snapshotId, title, assistantText;
  final int version;
  final List<BatchConfirmationSection> sections;
  final List<BatchConfirmationRecipient> recipients;
  final List<ConfirmationRow> issues, rules;
  final ({int original, int callable, int skipped})? summary;
  final BatchConfirmationDecision decision;
  String get billingAlias => 'batch-plus:${snapshotId.trim()}:$version';
  bool get capturesBilling => decision == BatchConfirmationDecision.pending;
  bool get showsAssistantText =>
      assistantText.trim().isNotEmpty &&
      !const {
        '需要你补充信息',
        '需要你补充信息。',
        '请补充信息',
        '请补充必要信息',
        '请语音回答',
      }.contains(assistantText.trim());
  int get originalCount => summary == null
      ? recipients.length
      : summary!.original < recipients.length
      ? recipients.length
      : summary!.original;
  int get callableCount =>
      summary?.callable.clamp(0, originalCount) ??
      recipients.where((r) => r.runnable).length;
  int get skippedCount =>
      summary?.skipped.clamp(0, originalCount) ?? originalCount - callableCount;
  bool get hasAudit =>
      recipients.isNotEmpty ||
      issues.isNotEmpty ||
      (summary?.original ?? 0) > 0;

  BatchConfirmation withAssistantText(String text) => BatchConfirmation(
    snapshotId: snapshotId,
    version: version,
    title: title,
    sections: sections,
    recipients: recipients,
    issues: issues,
    rules: rules,
    assistantText: text,
    summary: summary,
    decision: decision,
  );

  BatchConfirmation updatedBy(BatchConfirmation update) => BatchConfirmation(
    snapshotId: snapshotId,
    version: version,
    title: update.title.trim().isEmpty ? title : update.title,
    sections: update.sections.isEmpty ? sections : update.sections,
    recipients: update.recipients.isEmpty ? recipients : update.recipients,
    issues: update.issues.isEmpty ? issues : update.issues,
    rules: update.rules.isEmpty ? rules : update.rules,
    summary: summary,
    assistantText: update.assistantText.trim().isEmpty
        ? assistantText
        : update.assistantText,
    decision: update.decision,
  );

  static BatchConfirmation? request(Map<String, Object?> payload) {
    final id = _text(payload, 'toolCallId');
    if (payload['toolName'] != 'confirmBatchTask' ||
        payload['displayPayloadVersion'] != 1 ||
        id.trim().isEmpty) {
      return null;
    }
    Object? snapshot = _object(payload['arguments'])?['snapshotJson'];
    if (snapshot is String) {
      try {
        snapshot = jsonDecode(snapshot);
      } catch (_) {
        return null;
      }
    }
    final data = _object(snapshot);
    if (data == null) return null;
    final summary = _object(data['contactSummary']);
    final title = _text(data, 'title'),
        assistant = _text(payload, 'assistantText');
    final recipients = data['recipients'] is List
        ? data['recipients'] as List
        : const [];
    return BatchConfirmation(
      snapshotId: id,
      version: _integer(payload['ordinal']) + 1,
      title: title.trim().isEmpty ? '任务确认' : title,
      sections: List.unmodifiable(
        _objects(data['sections']).map(
          (section) => BatchConfirmationSection(
            _text(section, 'title'),
            _rows(section['rows']),
          ),
        ),
      ),
      recipients: List.unmodifiable([
        for (final (index, item) in recipients.indexed)
          if (_object(item) case final row?)
            BatchConfirmationRecipient(
              id: _text(row, 'itemId').trim().isEmpty
                  ? '$id:recipient:$index'
                  : _text(row, 'itemId'),
              name: _text(row, 'targetName'),
              // The backend's contact resolver has emitted the same resolved
              // number under a few historical keys.  Keep the canonical key
              // first, then accept those aliases instead of rendering a
              // callable contact as missing a phone number.
              phone: _phone(row),
              salutation: _text(row, 'salutation'),
              status: _text(row, 'status'),
              detail: _text(row, 'detail'),
            ),
      ]),
      issues: List.unmodifiable(
        _objects(data['issues']).map(
          (row) => ConfirmationRow(_text(row, 'title'), _text(row, 'detail')),
        ),
      ),
      rules: _rows(data['rules']),
      summary: summary == null
          ? null
          : (
              original: _integer(summary['originalCount']).clamp(0, 0x7fffffff),
              callable: _integer(summary['callableCount']).clamp(0, 0x7fffffff),
              skipped: _integer(summary['skippedCount']).clamp(0, 0x7fffffff),
            ),
      assistantText: assistant.trim().isEmpty
          ? '请确认以上任务理解，确认后我再开始执行。'
          : assistant,
    );
  }

  BatchConfirmation withDecision(Object? value) => updatedBy(
    BatchConfirmation(
      snapshotId: snapshotId,
      version: version,
      title: '',
      sections: const [],
      recipients: const [],
      issues: const [],
      rules: const [],
      assistantText: '',
      decision: BatchConfirmationDecision.fromWire(value),
    ),
  );
  static List<ConfirmationRow> _rows(Object? value) => List.unmodifiable(
    _objects(
      value,
    ).map((row) => ConfirmationRow(_text(row, 'label'), _text(row, 'value'))),
  );
  static Iterable<Map<String, Object?>> _objects(Object? value) =>
      value is List ? value.whereType<Map<String, Object?>>() : const [];
  static Map<String, Object?>? _object(Object? value) =>
      value is Map<String, Object?> ? value : null;
  static String _text(Map<String, Object?> map, String key) =>
      switch (map[key]) {
        final String s => s,
        final num n => '$n',
        final bool b => '$b',
        _ => '',
      };
  static String _phone(Map<String, Object?> map) {
    for (final key in const [
      'phoneNumber',
      'phone',
      'mobile',
      'contactPhone',
      'targetPhone',
    ]) {
      final value = _text(map, key).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}
