/// Trusted platform receipt units: 1000 milliunits make one currency unit.
class PlatformPaymentAmount {
  const PlatformPaymentAmount._(this.currency, this.milliunits);
  final String currency, milliunits;

  static PlatformPaymentAmount? parse(String? currency, String? milliunits) {
    if (currency == null && milliunits == null) return null;
    if (currency == null ||
        milliunits == null ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        !RegExp(r'^[0-9]+$').hasMatch(milliunits)) {
      throw const FormatException('Invalid platform payment amount');
    }
    return PlatformPaymentAmount._(currency, milliunits);
  }

  String get display {
    final units = BigInt.parse(milliunits);
    final scale = BigInt.from(1000);
    final fraction = (units % scale)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$currency ${units ~/ scale}${fraction.isEmpty ? '' : '.$fraction'}';
  }
}
