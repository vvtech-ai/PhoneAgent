import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/sip/sip_authenticator.dart';
import '../../domain/sip/sip_message.dart';
import '../../domain/sip/sip_lease.dart';

class Md5SipAuthenticator implements SipAuthenticator {
  const Md5SipAuthenticator();
  @override
  String authorization(
    SipMessage response, {
    required String username,
    required String password,
    required String method,
    required String uri,
    required String cnonce,
  }) => SipDigestChallenge.fromMessage(response).authorization(
    username: username,
    password: password,
    method: method,
    uri: uri,
    cnonce: cnonce,
  );
}

class SipDigestChallenge {
  SipDigestChallenge._(this.parameters, this.proxy);
  final Map<String, String> parameters;
  final bool proxy;
  @override
  String toString() => 'SipDigestChallenge(<private>)';

  static SipDigestChallenge fromMessage(SipMessage message) {
    final proxy = message.header('proxy-authenticate');
    final header = proxy ?? message.header('www-authenticate');
    if (header == null ||
        !header.startsWith(RegExp(r'Digest\s', caseSensitive: false))) {
      throw const SipLeaseFailure('INVALID_SIP_CHALLENGE');
    }
    final value = header.substring(6).trim();
    final parts = <String>[];
    var quoted = false, escaped = false;
    var current = '';
    for (final code in value.runes) {
      final char = String.fromCharCode(code);
      if (escaped) {
        current += char;
        escaped = false;
        continue;
      }
      if (quoted && char == r'\') {
        current += char;
        escaped = true;
        continue;
      }
      if (char == '"') quoted = !quoted;
      if (char == ',' && !quoted) {
        parts.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    if (quoted || escaped) throw const SipLeaseFailure('INVALID_SIP_CHALLENGE');
    parts.add(current);
    final parameters = <String, String>{};
    for (final part in parts) {
      final index = part.indexOf('=');
      if (index < 1) throw const SipLeaseFailure('INVALID_SIP_CHALLENGE');
      final key = part.substring(0, index).trim().toLowerCase();
      var item = part.substring(index + 1).trim();
      if (item.startsWith('"') && item.endsWith('"')) {
        item = item
            .substring(1, item.length - 1)
            .replaceAllMapped(RegExp(r'\\(.)'), (match) => match.group(1)!);
      }
      if (parameters.containsKey(key)) {
        throw const SipLeaseFailure('INVALID_SIP_CHALLENGE');
      }
      parameters[key] = item;
    }
    if ((parameters['realm'] ?? '').isEmpty ||
        (parameters['nonce'] ?? '').isEmpty) {
      throw const SipLeaseFailure('INVALID_SIP_CHALLENGE');
    }
    return SipDigestChallenge._(Map.unmodifiable(parameters), proxy != null);
  }

  String authorization({
    required String username,
    required String password,
    required String method,
    required String uri,
    required String cnonce,
    int nonceCount = 1,
  }) {
    final algorithm = (parameters['algorithm'] ?? 'MD5').toUpperCase();
    final choices = parameters['qop']
        ?.split(',')
        .map((item) => item.trim().toLowerCase());
    if (algorithm != 'MD5' ||
        (choices != null && !choices.contains('auth')) ||
        nonceCount < 1 ||
        nonceCount > 0xffffffff) {
      throw const SipLeaseFailure('UNSUPPORTED_SIP_AUTH');
    }
    String hash(String value) => md5.convert(utf8.encode(value)).toString();
    String quote(String value) {
      if (value.contains(RegExp(r'[\r\n\x00]'))) {
        throw const SipLeaseFailure('INVALID_SIP_AUTH');
      }
      return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    }

    final realm = parameters['realm']!, nonce = parameters['nonce']!;
    final ha1 = hash('$username:$realm:$password'),
        ha2 = hash('${method.toUpperCase()}:$uri');
    final nc = nonceCount.toRadixString(16).padLeft(8, '0');
    final response = choices == null
        ? hash('$ha1:$nonce:$ha2')
        : hash('$ha1:$nonce:$nc:$cnonce:auth:$ha2');
    final parts = [
      'username="${quote(username)}"',
      'realm="${quote(realm)}"',
      'nonce="${quote(nonce)}"',
      'uri="${quote(uri)}"',
      'response="$response"',
      'algorithm=MD5',
      if (parameters['opaque'] != null)
        'opaque="${quote(parameters['opaque']!)}"',
      if (choices != null) ...[
        'qop=auth',
        'nc=$nc',
        'cnonce="${quote(cnonce)}"',
      ],
    ];
    return '${proxy ? 'Proxy-Authorization' : 'Authorization'}: Digest ${parts.join(', ')}';
  }
}
