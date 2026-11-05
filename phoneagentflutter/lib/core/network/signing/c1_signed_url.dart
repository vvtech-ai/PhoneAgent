import 'dart:convert';

/// Canonical URL rules shared by the current SDK API and Agent SSE services.
abstract final class C1SignedUrl {
  static String encode(String value) => utf8.encode(value).map((byte) {
    if ((byte >= 65 && byte <= 90) ||
        (byte >= 97 && byte <= 122) ||
        (byte >= 48 && byte <= 57) ||
        [45, 46, 95, 126].contains(byte)) {
      return String.fromCharCode(byte);
    }
    return '%${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }).join();

  static String _decode(String raw) {
    final source = utf8.encode(raw), bytes = <int>[];
    for (var i = 0; i < source.length; i++) {
      var value = source[i];
      if (value == 37) {
        if (i + 2 >= source.length) throw const FormatException('C1 URL');
        final hex = String.fromCharCodes(source.sublist(i + 1, i + 3));
        if (!RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(hex)) {
          throw const FormatException('C1 URL');
        }
        value = int.parse(hex, radix: 16);
        i += 2;
      }
      bytes.add(value);
    }
    return utf8.decode(bytes);
  }

  static String path(String raw) {
    if (!raw.startsWith('/') || raw.contains('?') || raw.contains('#')) {
      throw const FormatException('C1 URL');
    }
    if (raw == '/') return raw;
    return '/${raw.substring(1).split('/').map((segment) {
      final value = _decode(segment);
      if (value.isEmpty || value == '.' || value == '..' || value.contains('/') || value.contains('\\') || value.contains('\u0000')) {
        throw const FormatException('C1 URL');
      }
      return encode(value);
    }).join('/')}';
  }

  static String query(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains('+')) throw const FormatException('C1 URL');
    final pairs =
        raw.split('&').map((part) {
          final split = part.indexOf('=');
          final key = _decode(split < 0 ? part : part.substring(0, split));
          if (key.isEmpty) throw const FormatException('C1 URL');
          final value = _decode(split < 0 ? '' : part.substring(split + 1));
          return (encode(key), encode(value));
        }).toList()..sort((a, b) {
          final key = a.$1.compareTo(b.$1);
          return key != 0 ? key : a.$2.compareTo(b.$2);
        });
    return pairs.map((pair) => '${pair.$1}=${pair.$2}').join('&');
  }

  static Uri withQuery(Uri uri, Map<String, Object?>? values) => values == null
      ? uri
      : uri.replace(
          query: values.entries
              .map(
                (entry) =>
                    '${encode(entry.key)}=${encode(entry.value?.toString() ?? '')}',
              )
              .join('&'),
        );
}
