import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/invite_link_policy.dart';

/// Opt-in debug evidence contains no code, token, payload, or URL query values.
void inviteProtocolMetadata(
  Map<String, dynamic> data,
  InviteLinkPolicy policy,
) {
  assert(() {
    if (!const bool.fromEnvironment('ENABLE_INVITE_PROTOCOL_DIAGNOSTICS')) {
      return true;
    }
    final code = data['code'];
    final url = data['shareUrl'];
    final uri = url is String ? Uri.tryParse(url) : null;
    final rawCode = code is String ? code : '';
    final expiry = data['expiresAt'];
    final parsed = expiry is String ? DateTime.tryParse(expiry) : null;
    final meta = <String, Object?>{
      'stage': 'CLIENT_CODE_PARSE',
      'codeType': code.runtimeType.toString(),
      'codeLength': rawCode.runes.length,
      'codeValid': InviteLinkPolicy.validCode(rawCode),
      'scheme': uri?.scheme,
      'host': uri?.host,
      'path': uri?.path.replaceAll(
        rawCode.isEmpty ? '\u0000' : rawCode,
        '<code>',
      ),
      'codeKeyCount': uri?.queryParametersAll['code']?.length ?? 0,
      'inviteKeyCount': uri?.queryParametersAll['invite']?.length ?? 0,
      'queryMatchesCode':
          uri != null &&
          [
            ...?uri.queryParametersAll['code'],
            ...?uri.queryParametersAll['invite'],
          ].contains(rawCode),
      'incomingPolicyMatches': url is String && policy.parse(url) == rawCode,
      'expiryPresent': expiry != null,
      'expiryParseable': parsed != null,
      'expiryFuture': parsed?.isAfter(DateTime.now()),
      for (final k in ['confirmedUsed', 'reservedCount', 'available'])
        k: data[k] is int ? data[k] : null,
    };
    debugPrint('INVITE_PROTOCOL_META ${jsonEncode(meta)}');
    return true;
  }());
}

void inviteProtocolApiFailure(String path, String code) {
  assert(() {
    if (const bool.fromEnvironment('ENABLE_INVITE_PROTOCOL_DIAGNOSTICS') &&
        path == 'me/code') {
      const safe = {
        'INVALID_CODE',
        'INVITE_INVALID',
        'INVITE_CODE_FORMAT_INVALID',
        'INVITE_NOT_FOUND',
        'CONFIG_SYNC_PENDING',
        'CONFIG_SYNCING',
        'CONFIG_NOT_PUBLISHED',
        'EXTERNAL_INVITE_UNAVAILABLE',
      };
      debugPrint(
        'INVITE_PROTOCOL_META ${jsonEncode({'stage': 'API_CODE_FAILURE', 'requestPath': 'api/invite/me/code', 'code': safe.contains(code) ? code : 'OTHER'})}',
      );
    }
    return true;
  }());
}
