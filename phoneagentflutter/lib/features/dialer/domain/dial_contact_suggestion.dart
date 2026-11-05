import '../../contacts/domain/contact_records.dart';
import '../../contacts/domain/contact_pinyin_search.dart';
import '../../contacts/domain/contact_phone_policy.dart';
import 'dial_country.dart';
import 'dial_phone_policy.dart';

class DialContactEntry {
  const DialContactEntry(this.row, this.tokens, this.phone, this.fallbackName);
  final DeviceContactRow row;
  final List<String> tokens;
  final String phone, fallbackName;
  String get name => row.name.trim().isEmpty ? fallbackName : row.name.trim();
  String get identity =>
      row.contactId.isEmpty ? 'name:$name' : 'id:${row.contactId}';
}

class DialContactSuggestion {
  const DialContactSuggestion(this.entry, {this.digitStart, this.digitEnd});
  final DialContactEntry entry;
  final int? digitStart, digitEnd;
  String get name => entry.name;
  String get phone => entry.phone;
  ({String text, int? start, int? end}) get display {
    final number = DialSuggestionPolicy.numberParts(phone);
    final formatted = number.iso == null
        ? RegExp(
            r'.{1,4}',
          ).allMatches(number.digits).map((m) => m.group(0)!).join(' ')
        : DialPhonePolicy.display(number.digits, number.iso!);
    final text = number.prefix == '+'
        ? '+$formatted'
        : [number.prefix, formatted].where((s) => s.isNotEmpty).join(' ');
    if (digitStart == null || digitEnd == null) {
      return (text: text, start: null, end: null);
    }
    final prefixLength = number.prefix.isEmpty
        ? 0
        : number.prefix == '+'
        ? 1
        : number.prefix.length + 1;
    final positions = [
      for (var i = prefixLength; i < text.length; i++)
        if (RegExp('[0-9]').hasMatch(text[i])) i,
    ];
    return digitEnd! > positions.length
        ? (text: text, start: null, end: null)
        : (
            text: text,
            start: positions[digitStart!],
            end: positions[digitEnd! - 1] + 1,
          );
  }
}

/// v65 DialContactSuggestionPolicy; no Agent fuzzy scoring or cloud directory.
class DialSuggestionPolicy {
  const DialSuggestionPolicy(this.dictionary);
  final ContactNameDictionary dictionary;
  List<DialContactEntry> index(List<DeviceContactRow> rows) {
    final tokenizer = ContactPinyinSearch(dictionary);
    return List.unmodifiable([
      for (final row in rows)
        if (ContactPhonePolicy.resolve(
              row.phone,
              normalized: row.normalizedPhone,
            )
            case final value?)
          DialContactEntry(
            row,
            tokenizer.tokens(row.name),
            value.dial,
            value.lookup,
          ),
    ]);
  }

  static List<DialContactSuggestion> search(
    String raw,
    List<DialContactEntry> entries, {
    int limit = 10,
  }) {
    final query = raw.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(query) || limit <= 0) return const [];
    final groups = <String, List<DialContactEntry>>{};
    for (final entry in entries) {
      (groups[entry.identity] ??= []).add(entry);
    }
    final names = <DialContactSuggestion>[],
        numbers = <DialContactSuggestion>[];
    for (final group in groups.values) {
      final first = group.first;
      final tokens = first.tokens
          .map((s) => s.toUpperCase().replaceAll(RegExp('[^A-Z]'), ''))
          .where((s) => s.isNotEmpty)
          .toList();
      final initials = tokens.map((s) => s[0]).join();
      if (t9(initials).startsWith(query) ||
          t9(tokens.join()).startsWith(query)) {
        names.add(DialContactSuggestion(first));
      } else {
        for (final entry in group) {
          final start = numberParts(entry.phone).digits.indexOf(query);
          if (start >= 0) {
            numbers.add(
              DialContactSuggestion(
                entry,
                digitStart: start,
                digitEnd: start + query.length,
              ),
            );
          }
        }
      }
    }
    return List.unmodifiable([...names, ...numbers].take(limit));
  }

  static String t9(String text) {
    const groups = ['ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS', 'TUV', 'WXYZ'];
    return text.toUpperCase().split('').map((c) {
      final index = groups.indexWhere((g) => g.contains(c));
      return index < 0 ? '' : '${index + 2}';
    }).join();
  }

  static ({String digits, String prefix, String? iso}) numberParts(String raw) {
    final text = raw.trim();
    var digits = DialPhonePolicy.digits(text);
    if (!text.startsWith('+') && !text.startsWith('00')) {
      return (digits: digits, prefix: '', iso: 'CN');
    }
    if (text.startsWith('00')) digits = digits.substring(2);
    for (final country in dialCountries) {
      if (digits.startsWith(country.code.substring(1))) {
        return (
          digits: digits.substring(country.code.length - 1),
          prefix: country.code,
          iso: country.iso,
        );
      }
    }
    // Unknown international prefixes remain part of the subscriber match, as v65.
    return (digits: digits, prefix: '+', iso: null);
  }
}
