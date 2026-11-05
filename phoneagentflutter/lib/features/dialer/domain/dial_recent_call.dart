import 'contact_dial_input.dart';
import 'dial_country.dart';

enum DialRecentSource { system, app }

enum DialRecentKind { normal, translation, agent }

class DialRecentCall {
  const DialRecentCall({
    required this.id,
    required this.phone,
    required this.startedAtMillis,
    required this.source,
    this.name = '',
    this.kind = DialRecentKind.normal,
    this.countryIso = '',
    this.callerLanguage = '',
    this.peerLanguage = '',
  });
  final String id, phone, name, countryIso, callerLanguage, peerLanguage;
  final int startedAtMillis;
  final DialRecentSource source;
  final DialRecentKind kind;
  String get key => '${source.name}:$id';
  bool get selectable =>
      phone.trim().isNotEmpty && phone != '-1' && phone != '-2';

  /// Local translation archives may contain only the national number.
  String get restorablePhone {
    final value = phone.trim();
    final country = dialCountry(countryIso);
    if (source == DialRecentSource.system ||
        country == null ||
        value.isEmpty ||
        value.startsWith('+') ||
        value.startsWith('00') ||
        value.contains('*') ||
        value.contains('#')) {
      return value;
    }
    final parsed = contactDialInput(value, defaultIso: country.iso);
    return parsed.error.isEmpty ? '${country.code}${parsed.number}' : value;
  }
}

/// v65 merges by source/id, not by number; repeated calls remain visible.
List<DialRecentCall> mergeDialRecentCalls(
  Iterable<DialRecentCall> system,
  Iterable<DialRecentCall> app, {
  int limit = 20,
}) {
  if (limit <= 0) return const [];
  final unique = <String, DialRecentCall>{};
  for (final item in [...system, ...app]) {
    if (item.source == DialRecentSource.system ||
        item.kind == DialRecentKind.translation) {
      unique.putIfAbsent(item.key, () => item);
    }
  }
  // An explicit original index preserves Android's stable order on equal times.
  final indexed = unique.values.indexed.toList()
    ..sort((a, b) {
      final time = b.$2.startedAtMillis.compareTo(a.$2.startedAtMillis);
      return time == 0 ? a.$1.compareTo(b.$1) : time;
    });
  return List.unmodifiable(indexed.take(limit).map((item) => item.$2));
}
