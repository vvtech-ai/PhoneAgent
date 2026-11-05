import 'dart:convert';

class ConfirmationRow {
  const ConfirmationRow(this.label, this.value);
  final String label, value;
}

/// Shared live/history display; does not authorize or initiate a call.
class CallConfirmation {
  CallConfirmation({
    required this.targetName,
    required this.phoneNumber,
    required this.primaryGoal,
    required List<String> summaryLines,
    int? recipientCount,
    Map<String, Object?> sourceSpec = const {},
    this.fromBatchTool = false,
  }) : summaryLines = List.unmodifiable(summaryLines),
       sourceSpec = Map.unmodifiable(sourceSpec),
       recipientCount = _count(recipientCount, summaryLines, phoneNumber);
  final String targetName, phoneNumber, primaryGoal;
  final List<String> summaryLines;
  final int recipientCount;
  final Map<String, Object?> sourceSpec;
  final bool fromBatchTool;
  bool get isBatch => recipientCount > 1;
  bool get hasContent =>
      targetName.isNotEmpty ||
      phoneNumber.isNotEmpty ||
      primaryGoal.isNotEmpty ||
      summaryLines.isNotEmpty;

  bool sameIdentityAs(
    CallConfirmation other, {
    String? toolId,
    String? otherToolId,
  }) {
    final left = toolId?.trim() ?? '', right = otherToolId?.trim() ?? '';
    if (left.isNotEmpty && right.isNotEmpty) return left == right;
    if (left.isNotEmpty && !left.startsWith('timeline-item:') ||
        right.isNotEmpty && !right.startsWith('timeline-item:')) {
      return false;
    }
    return sameSpecAs(other);
  }

  bool sameSpecAs(CallConfirmation other) {
    // Match the native CallSpecPayload contract, excluding transport metadata.
    Object spec(CallConfirmation value) => {
      'targetName': value.targetName,
      'phoneNumber': value.phoneNumber,
      'scene': value.sourceSpec['scene'] ?? '',
      'primaryGoal': value.primaryGoal,
      'summaryLines': value.summaryLines,
      'negotiationRules': value.sourceSpec['negotiationRules'],
      'boundaries': value.sourceSpec['boundaries'],
      'recipientCount': int.tryParse(
        value.sourceSpec['recipientCount']?.toString() ?? '',
      ),
    };
    return fromBatchTool == other.fromBatchTool &&
        jsonEncode(_canonicalSpec(spec(this))) ==
            jsonEncode(_canonicalSpec(spec(other)));
  }

  static Object? _canonicalSpec(Object? value) {
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonicalSpec(value[key])};
    }
    if (value is List) return value.map(_canonicalSpec).toList();
    return value;
  }

  factory CallConfirmation.fromPayload(
    Map<String, Object?> data, {
    bool batch = false,
  }) {
    String text(String key) =>
        data[key] is String ? (data[key] as String).trim() : '';
    if (batch) {
      final recipients = _array(data['recipientsJson'])
          .whereType<Map>()
          .where(
            (m) =>
                m['targetName'] is String &&
                (m['targetName'] as String).trim().isNotEmpty,
          )
          .toList();
      final targets = recipients
          .map((r) => (r['targetName'] as String).trim())
          .join('、');
      return CallConfirmation(
        sourceSpec: data,
        fromBatchTool: true,
        targetName: targets,
        phoneNumber: recipients
            .map(_phone)
            .where((s) => s.isNotEmpty)
            .join('、'),
        primaryGoal: text('primaryGoal'),
        summaryLines: targets.isEmpty ? [] : ['联系人：$targets'],
        recipientCount: recipients.length,
      );
    }
    return CallConfirmation(
      sourceSpec: data,
      targetName: text('targetName'),
      phoneNumber: text('phoneNumber'),
      primaryGoal: text('primaryGoal'),
      summaryLines: _array(
        data['summaryLines'],
      ).whereType<String>().where((s) => s.trim().isNotEmpty).toList(),
      recipientCount: int.tryParse(data['recipientCount']?.toString() ?? ''),
    );
  }

  List<ConfirmationRow> get rows {
    final result = <ConfirmationRow>[
      if (targetName.isNotEmpty) ConfirmationRow('目标', targetName),
      if (!isBatch && phoneNumber.isNotEmpty)
        ConfirmationRow('电话', phoneNumber),
      if (primaryGoal.isNotEmpty) ConfirmationRow('目的', primaryGoal),
    ];
    final seen = <String>{};
    for (final line in summaryLines) {
      final row = _row(line);
      if (row == null || _internalKeys.contains(row.label.toLowerCase())) {
        continue;
      }
      if (seen.add('${row.label}\u0000${row.value}')) result.add(row);
    }
    return List.unmodifiable(result);
  }

  static ConfirmationRow? _row(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) return null;
    final separators = [
      normalized.indexOf('：'),
      normalized.indexOf(':'),
    ].where((i) => i > 0).toList()..sort();
    if (separators.isEmpty) return ConfirmationRow('信息', normalized);
    final index = separators.first;
    final label = normalized.substring(0, index).trim(),
        value = normalized.substring(index + 1).trim();
    return label.isEmpty || value.isEmpty
        ? null
        : ConfirmationRow(label, value);
  }

  static int _count(int? explicit, List<String> lines, String phone) {
    if (explicit != null && explicit > 0) return explicit;
    for (final line in lines) {
      final row = _row(line);
      if (row == null || !const {'联系人', '外呼对象', '拨打对象'}.contains(row.label)) {
        continue;
      }
      final count = row.value
          .split(RegExp('[、，,;；\n]+'))
          .where((s) => s.trim().isNotEmpty)
          .length;
      if (count > 1) return count;
    }
    final count = phone
        .split(RegExp('[，,;；\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    return count > 0 ? count : 1;
  }

  static List<Object?> _array(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    return value is List ? value : const [];
  }

  static String _phone(Map<dynamic, dynamic> recipient) {
    for (final key in const [
      'phoneNumber',
      'phone',
      'mobile',
      'contactPhone',
      'targetPhone',
    ]) {
      final value = recipient[key];
      final text = value is String ? value.trim() : '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static const _internalKeys = {
    'targetname',
    'phonenumber',
    'contactname',
    'resolvedname',
    'requestedname',
    'contactmatchtype',
    'matchtype',
    'contactid',
    'originaltargetname',
  };
}
