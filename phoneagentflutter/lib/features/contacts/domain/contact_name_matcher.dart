import 'contact_records.dart';
import 'contact_phone_policy.dart';
import 'contact_pinyin_search.dart';

enum ContactInputSource { unknown, typed, asr }

class ContactNameMatcher {
  ContactNameMatcher(
    List<DeviceContactRow> rows,
    ContactNameDictionary dictionary,
  ) : _pinyin = ContactPinyinSearch(dictionary),
      _rows = rows
          .map((row) {
            final phone = ContactPhonePolicy.resolve(
              row.phone,
              normalized: row.normalizedPhone,
            );
            return phone == null
                ? null
                : DeviceContactRow(
                    name: row.name.trim(),
                    phone: phone.lookup,
                    label: row.label,
                    contactId: row.contactId,
                  );
          })
          .whereType<DeviceContactRow>()
          .toList();
  final List<DeviceContactRow> _rows;
  final ContactPinyinSearch _pinyin;

  List<Map<String, Object?>> resolve(
    List<String> names,
    ContactInputSource source,
  ) {
    final requests = names
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final pinyin = source == ContactInputSource.asr
        ? _rows
              .map((r) => _pinyin.tokens(_pinyin.normalizeName(r.name)))
              .toList()
        : <List<String>>[];
    final known = pinyin
        .expand((v) => v)
        .where((s) => s.isNotEmpty && s != '?')
        .toSet();
    return requests.map((name) {
      final candidates = <String, DeviceContactRow>{};
      void add(DeviceContactRow row) {
        final key =
            '${_pinyin.normalizeName(row.name).toLowerCase()}\u0000${row.phone.trim()}';
        candidates.putIfAbsent(key, () => row);
      }

      String? matchType;
      if (source != ContactInputSource.asr) {
        final target = _pinyin.normalizeName(name).toLowerCase();
        _rows
            .where((r) => _pinyin.normalizeName(r.name).toLowerCase() == target)
            .forEach(add);
        if (candidates.isNotEmpty) matchType = 'name_exact';
      } else {
        _rows.where((r) => r.name == name).forEach(add);
        if (candidates.isNotEmpty) matchType = 'name_exact';
        if (candidates.isEmpty) {
          _rows
              .where((r) => r.name.toLowerCase().contains(name.toLowerCase()))
              .forEach(add);
          if (candidates.isNotEmpty) matchType = 'name_like';
        }
        final before = candidates.length;
        final query = _pinyin.tokens(name, known);
        final matches = <(DeviceContactRow, double)>[];
        for (var i = 0; i < _rows.length; i++) {
          final score = ContactPinyinSearch.score(query, pinyin[i]);
          if (score != null) matches.add((_rows[i], score));
        }
        matches.sort((a, b) {
          var result = b.$2.compareTo(a.$2);
          if (result == 0) {
            result = a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
          }
          return result == 0 ? a.$1.phone.compareTo(b.$1.phone) : result;
        });
        for (final match in matches) {
          add(match.$1);
        }
        if (candidates.length > before) {
          matchType = before == 0
              ? 'pinyin_fallback'
              : '${matchType}_with_pinyin_candidates';
        }
      }
      final rows = candidates.values
          .map(
            (r) => <String, Object?>{
              'displayName': r.name.isEmpty ? name : r.name,
              'resolvedName': r.name.isEmpty ? name : r.name,
              'phoneNumber': r.phone,
              if (r.contactId.isNotEmpty) 'contactId': r.contactId,
              if (r.label.trim().isNotEmpty) 'label': r.label.trim(),
            },
          )
          .toList();
      final status = rows.isEmpty
          ? 'NOT_FOUND'
          : rows.length == 1 && matchType != 'pinyin_fallback'
          ? 'RESOLVED'
          : 'MULTIPLE_CANDIDATES';
      return <String, Object?>{
        'name': name,
        'requestedName': name,
        'status': status,
        'inputSource': source.name,
        if (matchType != null) 'matchType': matchType,
        if (rows.isNotEmpty) 'candidates': rows,
        if (status == 'RESOLVED') ...rows.single,
      };
    }).toList();
  }
}
