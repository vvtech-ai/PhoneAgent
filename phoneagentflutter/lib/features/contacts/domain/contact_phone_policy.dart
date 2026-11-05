/// Port of v65 DeviceContactPhoneCountryPolicy; not a dial-admission policy.
class ContactPhoneValue {
  const ContactPhoneValue(this.lookup, this.dial, this.country, this.national);
  final String lookup, dial, national;
  final String? country;
}

abstract final class ContactPhonePolicy {
  static String digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Directory keys differ from system dial strings, which must remain intact.
  static String directoryKey(String raw) {
    final value = digits(raw);
    if (value.length > 11 && value.startsWith('0086')) {
      return value.substring(4);
    }
    if (value.length > 11 && value.startsWith('86')) return value.substring(2);
    return value;
  }

  static bool _international(String value) =>
      value.startsWith('+') || value.startsWith('00');

  static ContactPhoneValue? resolve(String raw, {String normalized = ''}) {
    raw = raw.trim();
    normalized = normalized.trim();
    final international = _international(normalized)
        ? normalized
        : _international(raw)
        ? raw
        : null;
    if (international != null) {
      if (!RegExp(r'^[0-9+ ()（）.\-]+$').hasMatch(international)) return null;
      var value = digits(international);
      if (international.startsWith('00')) value = value.substring(2);
      if (value.isEmpty) return null;
      String? country;
      var national = value;
      for (final entry in const {
        '86': 'CN',
        '65': 'SG',
        '81': 'JP',
        '1': 'US',
      }.entries) {
        if (!value.startsWith(entry.key)) continue;
        country = entry.value;
        national = value.substring(entry.key.length);
        if (national.isEmpty) return null;
        break;
      }
      var lookup = country == 'CN' ? national : '+$value';
      if (country == 'CN' && !_international(raw)) {
        final local = normalizeLocal(raw);
        if (local.isNotEmpty) lookup = local;
      }
      return ContactPhoneValue(lookup, '+$value', country, national);
    }
    final local = normalizeLocal(normalized.isEmpty ? raw : normalized);
    return local.isEmpty
        ? null
        : ContactPhoneValue(local, '+86$local', 'CN', local);
  }

  static String normalizeLocal(String raw) {
    final separator = RegExp(r'(?:转|ext\.?|x|#)', caseSensitive: false);
    final extension =
        RegExp(
          r'(?:转|ext\.?|x|#)\s*(\d{1,6})',
          caseSensitive: false,
        ).firstMatch(raw)?.group(1) ??
        '';
    final base = digits(raw.trim().split(separator).first);
    final mobile = directoryKey(base);
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile)) return mobile;
    if (base.length < 5 || base.length > 20) return '';
    return extension.isEmpty ? base : '$base-$extension';
  }
}
