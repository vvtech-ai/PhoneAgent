import 'dart:convert';
import 'sip_lease.dart';

class SipMessage {
  SipMessage._(this.startLine, this.status, this.headers, this.body);
  final String startLine, body;
  final int status;
  final Map<String, List<String>> headers;
  String? header(String name) => headers[_name(name)]?.firstOrNull;
  List<String> headerValues(String name) => headers[_name(name)] ?? const [];
  String get method => status == 0 ? startLine.split(' ').first : '';
  int? get cseq =>
      int.tryParse(header('cseq')?.split(RegExp(r'\s+')).first ?? '');
  String get cseqMethod =>
      header('cseq')?.split(RegExp(r'\s+')).last.toUpperCase() ?? '';

  /// Only the first Via hop identifies the client transaction.
  String? get topViaBranch {
    final via = header('via')?.split(',').first;
    if (via == null) return null;
    final parameters = via
        .split(';')
        .skip(1)
        .where((part) => part.split('=').first.trim().toLowerCase() == 'branch')
        .toList();
    if (parameters.length != 1) return null;
    return RegExp(
      r"^\s*branch\s*=\s*([A-Za-z0-9_.!%*+`'~-]+)\s*$",
      caseSensitive: false,
    ).firstMatch(parameters.single)?.group(1);
  }

  @override
  String toString() => 'SipMessage(status=$status)';

  static SipMessage parse(String raw) {
    if (utf8.encode(raw).length > 65536 || raw.contains('\x00')) {
      throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
    }
    var separator = raw.indexOf('\r\n\r\n');
    var offset = 4;
    if (separator < 0) {
      separator = raw.indexOf('\n\n');
      offset = 2;
    }
    if (separator < 0) throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
    final lines = raw
        .substring(0, separator)
        .replaceAll('\r\n', '\n')
        .split('\n');
    final start = lines.first;
    final response = RegExp(
      r'^SIP/2\.0 ([1-6][0-9]{2})(?: .*)?$',
    ).firstMatch(start);
    if (response == null &&
        !RegExp(r'^[A-Z]+ sip[s]?:\S+ SIP/2\.0$').hasMatch(start)) {
      throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
    }
    final unfolded = <String>[];
    for (final line in lines.skip(1)) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfolded.isEmpty) {
          throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
        }
        unfolded[unfolded.length - 1] += ' ${line.trim()}';
      } else {
        unfolded.add(line);
      }
    }
    final headers = <String, List<String>>{};
    for (final line in unfolded) {
      final colon = line.indexOf(':');
      if (colon < 1 || line.contains('\r')) {
        throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
      }
      final name = _name(line.substring(0, colon).trim());
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
        throw const SipLeaseFailure('INVALID_SIP_MESSAGE');
      }
      headers.putIfAbsent(name, () => []).add(line.substring(colon + 1).trim());
    }
    final body = raw.substring(separator + offset);
    final lengths = headers['content-length'];
    if (lengths != null &&
        (lengths.length != 1 ||
            int.tryParse(lengths.single) != utf8.encode(body).length)) {
      throw const SipLeaseFailure('INVALID_SIP_LENGTH');
    }
    return SipMessage._(
      start,
      int.parse(response?.group(1) ?? '0'),
      Map.unmodifiable(
        headers.map(
          (key, values) => MapEntry(key, List<String>.unmodifiable(values)),
        ),
      ),
      body,
    );
  }

  static String _name(String name) =>
      const {
        'v': 'via',
        'f': 'from',
        't': 'to',
        'i': 'call-id',
        'm': 'contact',
        'l': 'content-length',
        'c': 'content-type',
      }[name.toLowerCase()] ??
      name.toLowerCase();
}
