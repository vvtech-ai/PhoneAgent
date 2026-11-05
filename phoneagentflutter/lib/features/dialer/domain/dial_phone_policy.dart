import 'dial_country.dart';

/// v65 DialPhoneNumberPolicy; extension is separated and never auto-sent as DTMF.
class DialPhoneTarget {
  const DialPhoneTarget(this.number, this.extension, {this.networkNumber});
  final String number, extension;
  final String? networkNumber;
}

abstract final class DialPhonePolicy {
  static String digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Compatibility is enabled only by the format-warning confirmation owner.
  static DialPhoneTarget? resolveForCall(
    String raw,
    String countryIso, {
    DialCountry? configuredCountry,
    bool allowUnverifiedNumber = false,
  }) {
    final resolved = resolve(
      raw,
      countryIso,
      configuredCountry: configuredCountry,
    );
    if (resolved != null || !allowUnverifiedNumber) return resolved;
    final value = raw.trim();
    final country = configuredCountry?.iso == countryIso
        ? configuredCountry
        : dialCountry(countryIso);
    if (country == null || !RegExp(r'^[0-9]{3,14}$').hasMatch(value)) {
      return null;
    }
    final code = digits(country.code);
    if (code.isEmpty) return null;
    final china = countryIso == 'CN' || code == '86';
    final national = value.replaceFirst(RegExp(r'^0+'), '');
    final canonical = china && value.length <= 8 ? value : '+$code$national';
    return DialPhoneTarget(
      canonical,
      '',
      networkNumber: china ? value : '00$code$national',
    );
  }

  static DialPhoneTarget? resolve(
    String raw,
    String countryIso, {
    DialCountry? configuredCountry,
  }) {
    final country = configuredCountry?.iso == countryIso
        ? configuredCountry
        : dialCountry(countryIso);
    if (country == null) return null;
    var main = raw.trim().replaceFirst(RegExp(r'^tel:'), '');
    var extension = '';
    final explicit = RegExp(
      r'(?:转|ext\.?|x|#|\*)\s*(\d{1,6})\s*$',
      caseSensitive: false,
    ).firstMatch(main);
    if (explicit != null) {
      extension = explicit.group(1)!;
      main = main.substring(0, explicit.start);
    } else {
      final dash = RegExp(r'-\s*(\d{1,6})\s*$').firstMatch(main);
      if (dash != null &&
          digits(main).length > 12 &&
          digits(main.substring(0, dash.start)).length >= 3 &&
          digits(main.substring(0, dash.start)).length <= 12) {
        extension = dash.group(1)!;
        main = main.substring(0, dash.start);
      }
    }
    final compact = main.replaceAll(RegExp(r'[^0-9+]'), '');
    final numbers = digits(compact);
    if (numbers.isEmpty) return null;
    final foreign =
        compact.startsWith('+') && !compact.startsWith('+86') ||
        numbers.startsWith('00') && !numbers.startsWith('0086');
    if (foreign || country.iso != 'CN') {
      final canonical = compact.startsWith('+')
          ? compact
          : compact.startsWith('00')
          ? '+${compact.substring(2)}'
          : '${country.code}${numbers.replaceFirst(RegExp(r'^0+'), '')}';
      return RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(canonical)
          ? DialPhoneTarget(
              canonical,
              extension,
              networkNumber: '00${canonical.substring(1)}',
            )
          : null;
    }
    final explicitChina =
        compact.startsWith('+86') || numbers.startsWith('0086');
    final national = compact.startsWith('+86')
        ? numbers.substring(2)
        : numbers.startsWith('0086')
        ? numbers.substring(4)
        : numbers.startsWith('86') && numbers.length >= 12
        ? numbers.substring(2)
        : numbers;
    String? china(String value) {
      if (RegExp(r'^1[3-9][0-9]{9}$').hasMatch(value)) return '+86$value';
      if (RegExp(r'^0[0-9]{9,11}$').hasMatch(value)) {
        return '+86${value.substring(1)}';
      }
      if (RegExp(
        r'^(400[0-9]{7}|800[0-9]{7}|95[0-9]{3,8}|96[0-9]{3,8}|1[0-9]{4}|[0-9]{3,8})$',
      ).hasMatch(value)) {
        return value;
      }
      return null;
    }

    final number =
        china(national) ?? (explicitChina ? china('0$national') : null);
    return number == null
        ? null
        : DialPhoneTarget(
            number,
            extension,
            networkNumber: number.startsWith('+86')
                ? (national.startsWith('0') ||
                          RegExp(r'^1[3-9][0-9]{9}$').hasMatch(national)
                      ? national
                      : '0${number.substring(3)}')
                : number,
          );
  }

  static String display(String raw, String iso) {
    if (raw.contains('*') || raw.contains('#')) return raw;
    final value = digits(raw);
    final groups = switch (iso) {
      'US' => [3, 3, 4],
      'SG' => [4, 4],
      'JP' => value.startsWith('0') ? [3, 4, 4] : [2, 4, 4],
      _ => [3, 4, 4],
    };
    final parts = <String>[];
    var offset = 0;
    for (final size in groups) {
      if (offset >= value.length) break;
      final end = (offset + size).clamp(0, value.length);
      parts.add(value.substring(offset, end));
      offset = end;
    }
    if (offset < value.length) parts.add(value.substring(offset));
    return parts.join(' ');
  }
}
