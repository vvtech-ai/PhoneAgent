import 'sip_message.dart';

/// The peer request reverses the local/remote tags of the confirmed dialog.
bool matchesSipDialogBye(
  SipMessage request, {
  required String callId,
  required String localTag,
  required String remoteHeader,
}) {
  if (request.method != 'BYE' ||
      !RegExp(r'^\d+[ \t]+BYE$').hasMatch(request.header('cseq') ?? '') ||
      request.cseqMethod != 'BYE' ||
      request.cseq == null ||
      request.cseq! <= 0 ||
      request.cseq! > 0x7fffffff ||
      request.header('call-id') != callId ||
      [
        'from',
        'to',
        'call-id',
        'cseq',
      ].any((name) => request.headerValues(name).length != 1)) {
    return false;
  }
  final expected = sipAddressTag(remoteHeader);
  final from = sipAddressTag(request.header('from')!);
  final to = sipAddressTag(request.header('to')!);
  return expected.valid &&
      from.valid &&
      to.valid &&
      from.tag == expected.tag &&
      to.tag == localTag;
}

/// Quoted display names and angle-bracket URI parameters are not header tags.
({bool valid, String? tag}) sipAddressTag(String header) {
  const invalid = (valid: false, tag: null);
  if (!RegExp(r'sips?:[^\s<>;]+', caseSensitive: false).hasMatch(header) ||
      header.contains(RegExp(r'[\r\n\x00]'))) {
    return invalid;
  }
  var quoted = false, escaped = false, angle = false;
  final outside = StringBuffer();
  for (final code in header.runes) {
    final char = String.fromCharCode(code);
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        quoted = false;
      }
      continue;
    }
    if (char == '"' && !angle) {
      quoted = true;
      continue;
    }
    if (char == '<') {
      if (angle) return invalid;
      angle = true;
      continue;
    }
    if (char == '>') {
      if (!angle) return invalid;
      angle = false;
      continue;
    }
    if (!angle) outside.write(char);
  }
  if (quoted || escaped || angle) return invalid;
  final parameters = outside
      .toString()
      .split(';')
      .skip(1)
      .where((part) => part.split('=').first.trim().toLowerCase() == 'tag')
      .toList();
  if (parameters.isEmpty) return (valid: true, tag: null);
  if (parameters.length != 1) return invalid;
  final tag = RegExp(
    r"^\s*tag\s*=\s*([A-Za-z0-9_.!%*+`'~-]+)\s*$",
    caseSensitive: false,
  ).firstMatch(parameters.single)?.group(1);
  return tag == null ? invalid : (valid: true, tag: tag);
}
