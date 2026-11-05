import 'account_request_policy.dart';
import 'account_transport_policy.dart';
import '../diagnostics/clone_request_diagnostics.dart';
import '../diagnostics/ota_request_diagnostics.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'account_session.dart';
import 'account_error_mapping.dart';
import 'service_routes.dart';
import 'signing/c1_transport.dart';
import 'signing/c1_signed_url.dart';
import '../diagnostics/diagnostic_event.dart';
import 'account_protocol_diagnostics.dart';
import 'stream_client.dart'
    if (dart.library.js_interop) 'stream_client_web.dart';

part 'account_recording_stream.dart';
part 'account_session_invalidation.dart';

enum AccountIdempotencyHeader { legacy, standard }

/// Account-bound requests only. Public assets use an uncredentialed client;
/// private attachment bytes must use the bounded, same-origin download method.
class AccountApi {
  AccountApi(
    AppConfig config,
    this._session, {
    Dio? client,
    this.diagnostics,
    this.signing,
  }) : _client = client ?? Dio(),
       _binaryClient = client ?? createStreamClient(),
       _routes = ServiceRoutes(config) {
    _owner = _session.credentials;
    _client.options = BaseOptions(
      connectTimeout: AccountTransportPolicy.connectTimeout,
      receiveTimeout: AccountTransportPolicy.receiveTimeout,
      sendTimeout: AccountTransportPolicy.sendTimeout,
      followRedirects: false,
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    _binaryClient.options = _client.options.copyWith();
  }
  final Dio _client;
  final Dio _binaryClient;
  final ServiceRoutes _routes;
  final C1Transport? signing;
  final AccountSession _session;
  final DiagnosticSink? diagnostics;
  late final AccountCredentials? _owner;
  final Map<int, Future<AccountCredentials>> _refreshes = {};

  void close() {
    _client.close(force: true);
    if (!identical(_client, _binaryClient)) _binaryClient.close(force: true);
  }

  /// Authenticate the SSE handshake with the same owner, route and signing path.
  /// A 401 may be replayed once before a stream is accepted; accepted runs are never replayed.
  Future<ResponseBody> openAgentStream(
    Object body,
    CancelToken cancellation,
  ) async {
    final initial = _session.credentials;
    if (initial == null) throw ApiFailure.signedOut;
    if (_owner == null || !_owner.sameLogin(initial)) {
      throw ApiFailure.sessionChanged;
    }
    Future<Response<Object?>> send(AccountCredentials credential) =>
        _send(
          _uri('api/agent/chat/stream'),
          credential,
          'POST',
          body,
          null,
          true,
          responseType: ResponseType.stream,
          transport: _binaryClient,
          cancelToken: cancellation,
        ).timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            cancellation.cancel();
            throw ApiFailure.network;
          },
        );
    var response = await send(initial);
    _assertCurrent(initial);
    if (response.statusCode == 401) {
      if (await _streamSignatureRejected(response.data)) {
        throw ApiFailure.rejected;
      }
      final credential = await _refresh(initial);
      _assertCurrent(initial);
      if (cancellation.isCancelled) throw ApiFailure.network;
      response = await send(credential);
      _assertCurrent(initial);
    }
    if (response.statusCode == 401) throw ApiFailure.signedOut;
    if (response.statusCode != 200 || response.data is! ResponseBody) {
      await AccountTransportPolicy.rejectHandshake(
        response.data is ResponseBody ? response.data as ResponseBody : null,
        response.statusCode ?? 0,
      );
    }
    return response.data as ResponseBody;
  }

  Future<Object?> request(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, Object?>? query,
    bool unwrapEnvelope = true,
    Set<int> exposedStatuses = const {},
    Set<String> exposedCodes = const {},
    AccountErrorMessageMapper? exposedMessage,
    String? idempotencyKey,
    AccountIdempotencyHeader idempotencyHeader =
        AccountIdempotencyHeader.legacy,
    Set<String> exposedDataCodes = const {},
    Set<String> exposedDataStages = const {},
    int? clonePricePoints,
  }) async {
    final uri = _uri(path);
    validateAccountRequest(
      path,
      method,
      idempotencyKey,
      idempotencyHeader == AccountIdempotencyHeader.standard,
      clonePricePoints,
    );
    final initial = _session.credentials;
    if (initial == null) throw ApiFailure.signedOut;
    if (_owner == null || !_owner.sameLogin(initial)) {
      throw ApiFailure.sessionChanged;
    }
    final protected = _protected(path);
    var response = await _send(
      uri,
      initial,
      method,
      body,
      query,
      protected,
      idempotencyKey: idempotencyKey,
      idempotencyHeader: idempotencyHeader,
      clonePricePoints: clonePricePoints,
    );
    _assertCurrent(initial);
    var projectedMessage = projectAccountRequestError(
      response.data,
      response.statusCode ?? 0,
      exposedMessage,
      exposedDataStages,
    );
    if (protected && response.statusCode == 401) {
      final refreshed = await _refresh(initial);
      _assertCurrent(initial);
      response = await _send(
        uri,
        refreshed,
        method,
        body,
        query,
        true,
        idempotencyKey: idempotencyKey,
        idempotencyHeader: idempotencyHeader,
        clonePricePoints: clonePricePoints,
      );
      _assertCurrent(initial);
      projectedMessage = projectAccountRequestError(
        response.data,
        response.statusCode ?? 0,
        exposedMessage,
        exposedDataStages,
      );
    }
    if (response.statusCode == 401) {
      throw path == 'api/ota/check'
          ? ApiFailure.rejected
          : ApiFailure.signedOut;
    }
    final payload = response.data;
    if (payload is Map &&
        ((response.statusCode ?? 500) >= 300 || !_success(payload['code']))) {
      throwAllowedAccountError(
        payload,
        response.statusCode ?? 0,
        codes: exposedCodes,
        dataCodes: exposedDataCodes,
        dataStages: exposedDataStages,
        projectedMessage: projectedMessage,
      );
    }
    if (exposedStatuses.contains(response.statusCode)) {
      throw ApiHttpFailure(response.statusCode!);
    }
    if ((response.statusCode ?? 500) >= 300) throw ApiFailure.rejected;
    return unwrapEnvelope ? unwrap(response.data) : response.data;
  }

  /// No URL or redirect from a response is followed with credentials. The
  /// stream is cancelled on overflow, account change, timeout or any failure.
  Future<Uint8List> download(
    String path, {
    required int maxBytes,
    required Set<String> mediaTypes,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path);
    if (maxBytes <= 0 || mediaTypes.isEmpty) throw ApiFailure.invalidResponse;
    final initial = _session.credentials;
    if (initial == null) throw ApiFailure.signedOut;
    if (_owner == null || !_owner.sameLogin(initial)) {
      throw ApiFailure.sessionChanged;
    }
    var cancellation = CancelToken();
    // Dio may eagerly buffer ahead of the async consumer (XHR also buffers).
    // Bound reception as well as the returned bytes. Reserve a small allowance
    // for an authentication error body when the expected image is tiny.
    final receiveBudget = maxBytes < 64 * 1024 ? 64 * 1024 : maxBytes;
    ApiFailure? aborted;
    Future<Response<Object?>> send(AccountCredentials credentials) {
      final requestToken = cancellation;
      return _send(
        uri,
        credentials,
        'GET',
        null,
        query,
        _protected(path),
        responseType: ResponseType.stream,
        transport: _binaryClient,
        cancelToken: requestToken,
        onReceiveProgress: (received, total) {
          if (requestToken.isCancelled) return;
          if (!initial.sameLogin(_session.credentials)) {
            aborted = ApiFailure.sessionChanged;
          } else if (received > receiveBudget || total > receiveBudget) {
            aborted = ApiFailure.invalidResponse;
          }
          if (aborted != null) requestToken.cancel();
        },
      );
    }

    try {
      var response = await send(initial);
      _assertCurrent(initial);
      if (_protected(path) && response.statusCode == 401) {
        final denied = response.data;
        if (await _streamSignatureRejected(denied)) throw ApiFailure.rejected;
        cancellation.cancel();
        final refreshed = await _refresh(initial);
        _assertCurrent(initial);
        cancellation = CancelToken();
        response = await send(refreshed);
        _assertCurrent(initial);
      }
      if (response.statusCode == 401) throw ApiFailure.signedOut;
      if (response.statusCode != 200) throw ApiFailure.rejected;
      final body = response.data;
      final type = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final declared = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (body is! ResponseBody ||
          !mediaTypes.contains(type) ||
          (declared != null && (declared < 0 || declared > maxBytes))) {
        throw ApiFailure.invalidResponse;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 30),
      )) {
        _assertCurrent(initial);
        if (bytes.length + chunk.length > maxBytes) {
          throw ApiFailure.invalidResponse;
        }
        bytes.add(chunk);
      }
      _assertCurrent(initial);
      if (bytes.isEmpty || (declared != null && bytes.length != declared)) {
        throw ApiFailure.invalidResponse;
      }
      return bytes.takeBytes();
    } on ApiFailure {
      if (aborted != null) throw aborted!;
      rethrow;
    } on DioException {
      throw aborted ?? ApiFailure.network;
    } on TimeoutException {
      throw ApiFailure.network;
    } finally {
      cancellation.cancel();
    }
  }

  Uri _uri(String path) {
    // The route resolver validates segments, including the narrow artifact ID contract.
    return _routes.resolve(path);
  }

  static bool _protected(String path) => AccountTransportPolicy.protected(path);

  void _assertCurrent(AccountCredentials expected) {
    if (!expected.sameLogin(_session.credentials)) {
      throw ApiFailure.sessionChanged;
    }
  }

  Future<Response<Object?>> _send(
    Uri uri,
    AccountCredentials credentials,
    String method,
    Object? body,
    Map<String, Object?>? query,
    bool protected, {
    ResponseType responseType = ResponseType.json,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Dio? transport,
    String? idempotencyKey,
    AccountIdempotencyHeader idempotencyHeader =
        AccountIdempotencyHeader.legacy,
    int? clonePricePoints,
    Map<String, String> contentHeaders = const {},
  }) async {
    _assertCurrent(credentials);
    final target = C1SignedUrl.withQuery(uri, query);
    final signed = await signing?.prepare(
      target,
      service: _routes.serviceOf(uri),
      method: method,
      token: protected ? credentials.token : '',
      body: body,
    );
    _assertCurrent(credentials);
    final cloneLog = CloneRequestDiagnostics(
      diagnostics,
      '/${_routes.logicalPathOf(uri)}',
      request: body,
    );
    final trace = signed?.$2['X-Reqid'] as String? ?? '';
    cloneLog.started(trace);
    final otaLog = OtaRequestDiagnostics(
      diagnostics,
      _routes.logicalPathOf(uri),
    );
    otaLog.started();
    final watch = Stopwatch()..start();
    try {
      final response = await (transport ?? _client).requestUri<Object?>(
        target,
        data: signed?.$1 ?? (body is FormData ? body.clone() : body),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          method: method,
          responseType: responseType,
          receiveTimeout: responseType == ResponseType.stream
              ? Duration.zero
              : null,
          headers: {
            ...contentHeaders,
            ...?signed?.$2,
            if (clonePricePoints != null)
              'X-Expected-Clone-Price-Points': '$clonePricePoints',
            if (uri.path.endsWith('/api/agent/chat/stream'))
              'Accept': 'text/event-stream',
            if (!uri.path.endsWith('/api/auth/voice-clone/refresh'))
              'X-Account-Id': credentials.accountId,
            if (protected) 'Authorization': 'Bearer ${credentials.token}',
            if (idempotencyKey != null)
              (idempotencyHeader == AccountIdempotencyHeader.standard
                      ? 'Idempotency-Key'
                      : 'X-Idempotency-Key'):
                  idempotencyKey,
          },
        ),
      );
      emitDiagnostic(
        diagnostics,
        DiagnosticEvent(
          operation: DiagnosticOperation.accountRequest,
          result: (response.statusCode ?? 500) < 300
              ? DiagnosticResult.succeeded
              : DiagnosticResult.failed,
          statusCode: response.statusCode ?? 0,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
      accountProtocolMetadata(uri, response.statusCode, response.data);
      otaLog.response(
        response.statusCode ?? 0,
        response.data,
        watch.elapsedMilliseconds,
      );
      cloneLog.response(
        response.statusCode ?? 0,
        response.data,
        watch.elapsedMilliseconds,
        trace,
      );
      await _checkSessionInvalidation(response, credentials, protected);
      return response;
    } on DioException catch (error) {
      if (!credentials.sameLogin(_session.credentials)) throw ApiFailure.sessionChanged;
      otaLog.failed(watch.elapsedMilliseconds);
      cloneLog.failed(error, watch.elapsedMilliseconds, trace);
      emitDiagnostic(
        diagnostics,
        DiagnosticEvent(
          operation: DiagnosticOperation.accountRequest,
          result: DiagnosticResult.failed,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
      throw ApiFailure.network;
    }
  }

  Future<AccountCredentials> _refresh(AccountCredentials initial) async {
    _assertCurrent(initial);
    final current = _session.credentials!;
    if (current.token != initial.token) return current;
    final pending = _refreshes[initial.epoch];
    if (pending != null) return pending;
    final operation = _refreshOnce(initial);
    _refreshes[initial.epoch] = operation;
    try {
      return await operation;
    } finally {
      _refreshes.remove(initial.epoch);
    }
  }

  Future<AccountCredentials> _refreshOnce(AccountCredentials initial) async {
    Response<Object?> response;
    try {
      response = await _send(
        _uri('api/auth/voice-clone/refresh'),
        initial,
        'POST',
        '',
        null,
        true,
      );
    } on DioException {
      throw ApiFailure.network;
    }
    _assertCurrent(initial);
    if (accountSignatureRejected(response.data)) throw ApiFailure.rejected;
    if (response.statusCode == 401) {
      await _session.rejectSession(initial);
      throw ApiFailure.signedOut;
    }
    if ((response.statusCode ?? 500) >= 300) throw ApiFailure.rejected;
    final data = object(unwrap(response.data));
    final token = data['voiceCloneAccessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    if (!await _session.replaceToken(initial, token.trim())) {
      throw ApiFailure.sessionChanged;
    }
    _assertCurrent(initial);
    return _session.credentials!;
  }

  static Object? unwrap(Object? value) {
    final root = object(value);
    if (root['code'] is! num && root['code'] is! String) {
      throw ApiFailure.invalidResponse;
    }
    if (!_success(root['code'])) throw ApiFailure.rejected;
    return root['data'];
  }

  static bool _success(Object? code) => code == 0 || code == '000000';

  /// Shared refresh ownership for SSE: only retry a rejected handshake, never a run.
  Future<AccountCredentials> refreshCredentials(AccountCredentials initial) =>
      _refresh(initial);

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) throw ApiFailure.invalidResponse;
    return value;
  }
}
