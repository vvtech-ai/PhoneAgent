abstract interface class ContactNameDictionary {
  String simplify(String value);
  bool isChinese(String character);
  String? firstPinyin(String character);
}

/// v65 ContactPinyinSearchEngine scoring; dictionary conversion stays in Dart.
class ContactPinyinSearch {
  const ContactPinyinSearch(this.dictionary);
  final ContactNameDictionary dictionary;
  String normalizeName(String value) => dictionary.simplify(value.trim());

  List<String> tokens(String value, [Set<String> known = const {}]) {
    final result = <String>[];
    var latin = '';
    void flush() {
      if (latin.isEmpty) return;
      final word = latin.toUpperCase().replaceAll(RegExp('[^A-Z?]'), '');
      latin = '';
      if (word.isEmpty) return;
      if (known.isEmpty || known.contains(word)) {
        result.add(word);
        return;
      }
      final split = <String>[];
      var index = 0;
      while (index < word.length) {
        final matches =
            known
                .where((s) => s.isNotEmpty && word.startsWith(s, index))
                .toList()
              ..sort((a, b) => b.length.compareTo(a.length));
        if (matches.isEmpty) {
          result.add(word);
          return;
        }
        split.add(matches.first);
        index += matches.first.length;
      }
      result.addAll(split);
    }

    for (final rune in value.runes) {
      final c = String.fromCharCode(rune);
      if (dictionary.isChinese(c)) {
        flush();
        final reading = dictionary.firstPinyin(c);
        if (reading != null) {
          final token = reading.toUpperCase().replaceAll(RegExp('[^A-Z?]'), '');
          if (token.isNotEmpty) result.add(token);
        }
      } else if (RegExp('[A-Za-z]').hasMatch(c)) {
        latin += c;
      } else if (rune >= 48 && rune <= 57) {
        flush();
        final digit = '零一二三四五六七八九'[rune - 48];
        final reading = dictionary.firstPinyin(digit);
        if (reading != null) result.add(reading.toUpperCase());
      } else {
        flush();
        if (c == '?') result.add(c);
      }
    }
    flush();
    return result;
  }

  static double? score(List<String> query, List<String> target) {
    if (query.isEmpty || query.length > 4 || target.isEmpty) return null;
    final full = _match(query, target, 0);
    final last = query.length >= 2 && target.length > 2
        ? _match(query.sublist(query.length - 2), target, target.length - 2)
        : null;
    final a = full == null ? null : 100 * full;
    final b = last == null ? null : 80 * last;
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }

  static double? _match(List<String> query, List<String> target, int start) {
    if (start < 0 || start + query.length > target.length) return null;
    var score = 1.0;
    for (var i = 0; i < query.length; i++) {
      if (query[i] == '?') continue;
      final weight = variants(query[i])[target[start + i]];
      if (weight == null) return null;
      score *= weight;
    }
    return score;
  }

  static Map<String, double> variants(String token) {
    token = token.toUpperCase();
    final values = <String, double>{token: 1};
    void add(String? value, double weight) {
      if (value != null && weight > (values[value] ?? 0)) {
        values[value] = weight;
      }
    }

    for (final rule in _finals) {
      add(_suffix(token, rule), rule.$3);
    }
    for (final rule in _initials) {
      final initial = _prefix(token, rule);
      add(initial, rule.$3);
      if (initial != null) {
        for (final suffix in _finals) {
          add(_suffix(initial, suffix), rule.$3 * suffix.$3);
        }
      }
    }
    for (final rule in _special) {
      add(
        token == rule.$1
            ? rule.$2
            : token == rule.$2
            ? rule.$1
            : null,
        rule.$3,
      );
    }
    return values;
  }

  static String? _suffix(String value, (String, String, double) rule) {
    final (a, b, _) = rule;
    if (b == 'UN' && !value.startsWith('C')) return null;
    if (value.endsWith(a)) {
      return value.substring(0, value.length - a.length) + b;
    }
    if (value.endsWith(b)) {
      return value.substring(0, value.length - b.length) + a;
    }
    return null;
  }

  static String? _prefix(String value, (String, String, double) rule) {
    final (a, b, _) = rule;
    if (b == 'T' && !value.endsWith('ANG')) return null;
    if (value.startsWith(b)) return a + value.substring(b.length);
    if (value.startsWith(a)) return b + value.substring(a.length);
    return null;
  }

  static const _finals = [
    ('IN', 'ING', .95),
    ('AN', 'ANG', .95),
    ('EN', 'ENG', .95),
    ('ON', 'ONG', .95),
    ('UAN', 'UANG', .95),
    ('UN', 'ONG', .60),
    ('UN', 'IONG', .60),
    ('EN', 'UN', .80),
  ];
  static const _initials = [
    ('Z', 'ZH', .90),
    ('C', 'CH', .90),
    ('S', 'SH', .90),
    ('H', 'F', .75),
    ('G', 'K', .75),
    ('L', 'N', .75),
    ('L', 'R', .75),
    ('CH', 'T', .75),
  ];
  static const _special = [
    ('HUANG', 'WANG', .80),
    ('HU', 'WU', .80),
    ('HUI', 'FEI', .80),
    ('CONG', 'CHUN', .60),
  ];
}
