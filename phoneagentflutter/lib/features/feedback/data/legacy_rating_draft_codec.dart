import 'dart:convert';
import '../domain/task_rating.dart';
import '../domain/task_rating_draft_store.dart';

/// Fixed v65 Gson shape, not the current secure-storage envelope.
abstract final class LegacyRatingDraftCodec {
  static const maxBytes = 64 * 1024;

  static SavedRatingDraft? decode(String? raw) {
    if (raw == null) return null;
    try {
      if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
        throw const FormatException();
      }
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) throw const FormatException();
      int? score(String key) {
        final value = data[key];
        if (value == null) return null;
        if (value is! int || value < 1 || value > 5) {
          throw const FormatException();
        }
        return value;
      }

      final skip = data['cloneVoiceNotEvaluated'] ?? false;
      final suggestion = data['suggestion'] ?? '';
      final key = data['submissionKey'] ?? '';
      if (skip is! bool ||
          suggestion is! String ||
          key is! String ||
          key.length > 256 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(key)) {
        throw const FormatException();
      }
      return SavedRatingDraft(
        TaskRatingDraft(
          taskUnderstanding: score('taskUnderstanding'),
          aiCallPerformance: score('aiCallPerformance'),
          taskCompletion: score('taskCompletion'),
          cloneVoicePerformance: score('cloneVoicePerformance'),
          cloneVoiceNotEvaluated: skip,
          suggestion: suggestion,
        ),
        submissionKey: key,
      );
    } catch (_) {
      // Never include the original JSON or user-entered text in an exception.
      throw const FormatException('Legacy rating draft unavailable');
    }
  }
}
