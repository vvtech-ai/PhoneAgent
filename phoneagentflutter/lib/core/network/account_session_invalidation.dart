part of 'account_api.dart';

/// Central interception also covers SSE/download handshakes; accepted streams are untouched.
extension _AccountSessionInvalidation on AccountApi {
  Future<void> _checkSessionInvalidation(
    Response<Object?> response,
    AccountCredentials sent,
    bool protected,
  ) async {
    if (!protected || response.statusCode != 403) return;
    Object? payload = response.data;
    if (payload is ResponseBody) {
      final type = payload.headers[Headers.contentTypeHeader]?.firstOrNull
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (type != 'application/json' && type != 'application/problem+json') {
        return;
      }
      final bytes = BytesBuilder();
      await for (final chunk in payload.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > 64 * 1024) throw ApiFailure.rejected;
        bytes.add(chunk);
      }
      final body = bytes.takeBytes();
      response.data = ResponseBody.fromBytes(
        body,
        response.statusCode!,
        headers: payload.headers,
      );
      try {
        payload = jsonDecode(utf8.decode(body));
      } on FormatException {
        return;
      }
    }
    if (payload is! Map) return;
    final reason = switch (payload['code']) {
      'AC0010' => SessionInvalidationReason.cancellationPending,
      'AC0011' => SessionInvalidationReason.cancelled,
      'AC0012' => SessionInvalidationReason.revoked,
      _ => null,
    };
    if (reason == null) return;
    final target = _session;
    if (target is AccountSessionInvalidation) {
      await (target as AccountSessionInvalidation).invalidateSession(
        sent,
        reason,
      );
    }
    // Never expose a second business error/toast for a rejected old session.
    throw ApiFailure.sessionChanged;
  }
}
