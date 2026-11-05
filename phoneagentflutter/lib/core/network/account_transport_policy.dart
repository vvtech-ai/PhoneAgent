import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'account_session.dart';

abstract final class AccountTransportPolicy {
  static Object _handshakeFailure(int status) => status <= 0 || status == 200
      ? ApiFailure.network
      : ApiHttpFailure(status);

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 90);
  static const sendTimeout = Duration(seconds: 90);
  static bool protected(String path) => const [
    'api/commerce',
    'api/membership',
    'api/account/settings',
    'api/points',
    'api/invite',
    'api/agent',
    'api/agent-artifacts',
    'api/assistant',
    'api/client-sip',
    'api/task',
    'api/task-ratings',
    'api/agent-calls',
    'api/realtime-translation-calls',
    'api/v1/realtime-translation',
    'api/service-monitoring/client-translation',
    'api/logs/upload',
    'api/feedback',
  ].any((prefix) => path == prefix || path.startsWith('$prefix/'));

  /// Only bounded, recognized error metadata crosses the transport boundary.
  static Future<Never> rejectHandshake(ResponseBody? body, int status) async {
    if (body == null) throw _handshakeFailure(status);
    final type = body.headers[Headers.contentTypeHeader]?.firstOrNull
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (type != 'application/json' && type != 'application/problem+json') {
      await body.stream.listen((_) {}).cancel();
      throw _handshakeFailure(status);
    }
    final bytes = <int>[];
    try {
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > 65536) {
          throw _handshakeFailure(status);
        }
        bytes.addAll(chunk);
      }
    } catch (_) {
      // A broken error body cannot prove that the submitted command was rejected.
      throw _handshakeFailure(status);
    }
    Object? payload;
    try {
      payload = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw _handshakeFailure(status);
    }
    if (payload is Map) {
      final data = payload['data'] is Map ? payload['data'] as Map : payload;
      final code = data['errorCode'] ?? payload['code'];
      if (const {
        'MODEL_TIMEOUT',
        'MODEL_RATE_LIMIT',
        'MODEL_PROVIDER_UNAVAILABLE',
        'MODEL_CONTEXT_LIMIT',
        'MODEL_AUTH_OR_QUOTA',
        'MODEL_BAD_REQUEST',
        'INVALID_MODEL_HISTORY',
        'TOOL_EXECUTION_FAILED',
        'LEDGER_OR_STORAGE_FAILED',
        'RESPONSE_SERIALIZATION_FAILED',
        'EMPTY_MODEL_RESPONSE',
      }.contains(code)) {
        throw ApiCodeFailure(code as String, statusCode: status);
      }
    }
    throw _handshakeFailure(status);
  }
}
