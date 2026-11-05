import '../../../core/diagnostics/diagnostic_translation_details.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/translation_preparation_diagnostics.dart';
import 'translation_rejection_diagnostics.dart';
import 'package:dio/dio.dart';
import '../domain/translation_backend_session.dart';

/// One configured translation deployment, no account API token or redirects.
class HttpTranslationBackendRepository implements TranslationBackendRepository {
  HttpTranslationBackendRepository(this.base, {Dio? client, this.diagnostics})
    : _client = client ?? Dio() {
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !base.path.endsWith('/')) {
      throw const FormatException('Invalid translation service base');
    }
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: false,
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }
  // Service protocol identity, independent of the account owning local records.
  static const _serviceUserId = 'mobile-app-user';
  final Uri base;
  final Dio _client;
  final DiagnosticSink? diagnostics;

  @override
  Future<TranslationBackendSession> create(
    TranslationCreateRequest request,
  ) async {
    final body = request.toJson();
    Map<String, dynamic> data;
    try {
      data = await _post('', request.userId, body);
    } on _CreateRequestFailure {
      // Match native IOException fallback, including HTTP and network failures.
      // A second failure escapes; successful-response decoding never retries.
      final legacy = Map<String, Object?>.of(body)..remove('capabilities');
      data = await _post('', request.userId, legacy);
    }
    final id = _text(data, 'callSessionId');
    _id(id);
    try {
      return _decodeSession(data, id, body['realtimeProvider'] as String);
    } catch (_) {
      // The server has already allocated a known session. Do not leak it when
      // later connection/recording fields are malformed, and never recreate it.
      try {
        await _post('/$id/hangup', request.userId, null, allowEmpty: true);
      } catch (_) {
        throw const TranslationBackendFailure(
          'INVALID_RESPONSE_CLEANUP_FAILED',
        );
      }
      rethrow;
    }
  }

  TranslationBackendSession _decodeSession(
    Map<String, dynamic> data,
    String id,
    String requestedProvider,
  ) {
    final cluster = _text(data, 'clusterId').toUpperCase();
    final grant = _text(data, 'recordingAccessGrant');
    if (!const {'US', 'JP'}.contains(cluster) || grant.isEmpty) _invalid();
    TranslationLiveKitConnection? liveKit;
    final raw = data['livekit'];
    if (raw is Map<String, dynamic>) {
      final url = _text(raw, 'url'), token = _text(raw, 'token');
      if (url.isNotEmpty && token.isNotEmpty) {
        _mediaUrl(url, const {'wss', 'https'});
        liveKit = TranslationLiveKitConnection(
          url: url,
          token: token,
          roomName: _text(raw, 'roomName'),
          participantIdentity: _text(raw, 'participantIdentity'),
        );
      }
    }
    final ws = _text(data, 'appAudioWsUrl');
    if (ws.isNotEmpty) _mediaUrl(ws, const {'wss'});
    if (liveKit == null && ws.isEmpty) _invalid();
    final transport = _text(data, 'mediaTransport');
    return TranslationBackendSession(
      id: id,
      clusterId: cluster,
      recordingAccessGrant: grant,
      mediaTransport: transport.isEmpty
          ? (liveKit != null ? 'livekit' : 'websocket')
          : transport,
      liveKit: liveKit,
      appAudioWsUrl: ws,
      voiceProvider: _text(data, 'voiceProvider').isEmpty
          ? 'twilio'
          : _text(data, 'voiceProvider'),
      realtimeProvider: _text(data, 'realtimeProvider').isEmpty
          ? requestedProvider
          : _text(data, 'realtimeProvider'),
      environment: _environment(data),
    );
  }

  @override
  Future<TranslationMerchantResult> startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  ) async {
    _id(session.id);
    request.toJson(); // Validate before any side effect.
    final data = await _post('/${session.id}/merchant-call', request.userId, {
      'merchantPhone': request.phone,
      'voiceProvider': session.voiceProvider,
    });
    if (data['started'] is! bool) _invalid();
    return TranslationMerchantResult(
      data['started'] as bool,
      environment: _environment(data),
    );
  }

  @override
  Future<void> hangup(TranslationBackendSession session, String userId) async {
    _id(session.id);
    await _post('/${session.id}/hangup', userId, null, allowEmpty: true);
  }

  Future<Map<String, dynamic>> _post(
    String suffix,
    String userId,
    Object? body, {
    bool allowEmpty = false,
  }) async {
    if (userId.trim().isEmpty || userId.contains(RegExp(r'[\r\n]'))) _invalid();
    final diagnosticStage = suffix.isEmpty
        ? 'overseasCreate'
        : suffix.endsWith('/hangup')
        ? 'overseasHangup'
        : 'overseasDial';
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.translationCall,
        result: DiagnosticResult.started,
        translation: DiagnosticTranslationDetails(
          diagnosticStage,
          'NATIVE_SERVICE_USER',
        ),
      ),
    );
    final Response<Object?> response;
    try {
      response = await _client.postUri<Object?>(
        base.resolve('api/app-translation-calls$suffix'),
        data: body,
        options: Options(headers: {'x-user-id': _serviceUserId}),
      );
    } on DioException {
      recordTranslationPreparation(
        diagnostics,
        diagnosticStage,
        DiagnosticResult.failed,
        error: const TranslationBackendFailure('NETWORK'),
      );
      throw const _CreateRequestFailure('NETWORK');
    }
    final status = response.statusCode ?? 0, value = response.data;
    if (status >= 200 && status < 300) {
      recordTranslationPreparation(
        diagnostics,
        diagnosticStage,
        DiagnosticResult.received,
        status: status,
      );
    }
    if (status < 200 || status >= 300) {
      recordTranslationRejection(
        diagnostics,
        diagnosticStage,
        status,
        value,
        body,
      );
      final data = value is Map<String, dynamic> ? value : <String, dynamic>{};
      final rawCode = data['code'] is String ? data['code'] : data['error'];
      throw _CreateRequestFailure(
        rawCode is String ? rawCode : 'HTTP',
        status: status,
        environment: _environment(data),
      );
    }
    if (allowEmpty && (value == null || value == '')) return {};
    if (value is! Map<String, dynamic>) _invalid();
    return value;
  }

  static String _text(Map<String, dynamic> data, String key) =>
      data[key] is String ? (data[key] as String).trim() : '';
  static Map<String, Object?> _environment(Map<String, dynamic> data) =>
      data['environment'] is Map<String, dynamic>
      ? Map.unmodifiable(data['environment'] as Map<String, dynamic>)
      : const {};
  static void _id(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) _invalid();
  }

  static void _mediaUrl(String value, Set<String> schemes) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !schemes.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      _invalid();
    }
  }

  static Never _invalid() =>
      throw const TranslationBackendFailure('INVALID_RESPONSE');
  void close() => _client.close(force: true);
}

/// HTTP/network failure only; response validation deliberately uses the base type.
class _CreateRequestFailure extends TranslationBackendFailure {
  const _CreateRequestFailure(super.code, {super.status, super.environment});
}
