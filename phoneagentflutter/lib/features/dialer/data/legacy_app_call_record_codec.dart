import 'dart:convert';
import '../domain/app_call_record_repository.dart';
import '../domain/dial_recent_call.dart';

/// v65 FinalCallRecordStorage plus its local recent-call metadata projection.
/// Old transcripts/results remain in the untouched source, never in this store.
abstract final class LegacyAppCallRecordCodec {
  static const maxBytes = 16 * 1024 * 1024;

  static List<DialRecentCall> decode(String? raw) {
    if (raw == null) return const [];
    try {
      if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
        throw const FormatException();
      }
      if (raw.trim().isEmpty) return const [];
      final rows = jsonDecode(raw);
      if (rows == null) return const [];
      if (rows is! List) throw const FormatException();
      final records = <DialRecentCall>[];
      for (final row in rows) {
        if (row is! Map) throw const FormatException();
        String text(String field) {
          final value = row[field];
          if (value == null) return '';
          if (value is! String) throw const FormatException();
          return value.trim();
        }

        final title = text('title');
        if (title.isEmpty || text('status').isEmpty || text('meta').isEmpty) {
          continue; // Same invalid-row filter as v65, not guessed defaults.
        }
        final kind = switch (text('callKind')) {
          'NORMAL' => DialRecentKind.normal,
          'TRANSLATION' => DialRecentKind.translation,
          _ => DialRecentKind.agent,
        };
        final at = row['occurredAtMillis'];
        if (at != null && at is! int) throw const FormatException();
        final time = at is int && at > 0 ? at : 0;
        final phone = text('phoneNumber');
        final callId = text('callId');
        final name = text('contactDisplayName');
        records.add(
          DialRecentCall(
            id: callId.isNotEmpty
                ? callId
                : '$phone:$time:${kind.name.toUpperCase()}',
            phone: phone,
            startedAtMillis: time,
            source: DialRecentSource.app,
            kind: kind,
            name: name.isNotEmpty ? name : _legacyName(title, phone),
            countryIso: text('dialCountryIso'),
            callerLanguage: text('callerLanguageCode'),
            peerLanguage: text('calleeLanguageCode'),
          ),
        );
      }
      return List.unmodifiable(records);
    } catch (_) {
      throw const AppCallRecordFailure('legacy-invalid-data');
    }
  }

  static String _legacyName(String title, String phone) {
    for (final prefix in const ['普通通话 ', '实时翻译 ', '翻译通话 ']) {
      if (!title.startsWith(prefix)) continue;
      final candidate = title.substring(prefix.length).trim();
      final numberDigits = phone.replaceAll(RegExp(r'\D'), '');
      final candidateDigits = candidate.replaceAll(RegExp(r'\D'), '');
      return candidate.isEmpty ||
              (numberDigits.isNotEmpty && numberDigits == candidateDigits)
          ? ''
          : candidate;
    }
    return '';
  }
}
