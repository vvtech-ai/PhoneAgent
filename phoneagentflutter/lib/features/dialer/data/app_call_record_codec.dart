import 'dart:convert';
import '../domain/dial_recent_call.dart';
import '../domain/app_call_record_repository.dart';

class AppCallRecordCodec {
  static List<DialRecentCall> decode(String scope, String? raw) {
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['version'] != 1 ||
          value['scope'] != scope ||
          value['records'] is! List) {
        throw const FormatException();
      }
      return List.unmodifiable(
        (value['records'] as List).map((row) {
          if (row is! Map ||
              row['id'] is! String ||
              (row['id'] as String).isEmpty ||
              row['phone'] is! String ||
              row['at'] is! int ||
              (row['at'] as int) < 0) {
            throw const FormatException();
          }
          String text(String key) {
            final value = row[key];
            if (value is! String) throw const FormatException();
            return value;
          }

          return DialRecentCall(
            id: text('id'),
            phone: text('phone'),
            startedAtMillis: row['at'] as int,
            source: DialRecentSource.app,
            kind: DialRecentKind.values.byName(text('kind')),
            name: text('name'),
            countryIso: text('country'),
            callerLanguage: text('callerLanguage'),
            peerLanguage: text('peerLanguage'),
          );
        }),
      );
    } catch (_) {
      throw const AppCallRecordFailure('invalid-data');
    }
  }

  static String encode(String scope, List<DialRecentCall> records) =>
      jsonEncode({
        'version': 1,
        'scope': scope,
        'records': records.map((row) {
          if (row.id.isEmpty ||
              row.startedAtMillis < 0 ||
              row.source != DialRecentSource.app) {
            throw const AppCallRecordFailure('invalid-record');
          }
          return {
            'id': row.id,
            'kind': row.kind.name,
            'phone': row.phone,
            'name': row.name,
            'at': row.startedAtMillis,
            'country': row.countryIso,
            'callerLanguage': row.callerLanguage,
            'peerLanguage': row.peerLanguage,
          };
        }).toList(),
      });
}
