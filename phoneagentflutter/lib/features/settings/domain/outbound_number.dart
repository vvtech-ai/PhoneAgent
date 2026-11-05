class OutboundNumber {
  const OutboundNumber(this.number, {required this.configured});
  final String number;
  final bool configured;

  String get masked {
    var mainland = number.trim().replaceAll(RegExp(r'\s+|-'), '');
    if (mainland.startsWith('+86')) mainland = mainland.substring(3);
    if (mainland.startsWith('86')) mainland = mainland.substring(2);
    if (!RegExp(r'^1[3-9][0-9]{9}$').hasMatch(mainland)) return number;
    return '${mainland.substring(0, 3)}****${mainland.substring(7)}';
  }
}

abstract interface class OutboundNumberRepository {
  Future<OutboundNumber> load();
  Future<OutboundNumber> save(String number);
  Future<OutboundNumber> delete();
}

/// Fixed v65 normalizeOutboundDialNumber, not the ordinary dialer policy.
String normalizeOutboundNumber(String value) {
  final input = value.trim();
  final result = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code >= 48 && code <= 57) {
      result.writeCharCode(code);
    } else if (code >= 0xff10 && code <= 0xff19) {
      result.writeCharCode(code - 0xff10 + 48);
    } else if (i == 0 && (code == 43 || code == 0xff0b)) {
      result.write('+');
    }
  }
  var number = result.toString();
  if (!number.startsWith('+86') && !number.startsWith('0086')) {
    return number;
  }
  number = number.substring(number.startsWith('+86') ? 3 : 4);
  if (number.isEmpty ||
      number.startsWith('0') ||
      RegExp(r'^1[3-9][0-9]{9}$').hasMatch(number)) {
    return number;
  }
  return '0$number';
}
