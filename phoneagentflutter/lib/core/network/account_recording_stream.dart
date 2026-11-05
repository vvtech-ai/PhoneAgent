part of 'account_api.dart';

Future<bool> _streamSignatureRejected(Object? body) async {
  if (body is! ResponseBody) return accountSignatureRejected(body);
  final mediaType = body.headers[Headers.contentTypeHeader]?.firstOrNull
      ?.split(';')
      .first
      .trim()
      .toLowerCase();
  if (mediaType != 'application/json' &&
      mediaType != 'application/problem+json') {
    await body.stream.listen((_) {}).cancel();
    return false;
  }
  final bytes = BytesBuilder();
  await for (final chunk in body.stream.timeout(const Duration(seconds: 20))) {
    if (bytes.length + chunk.length > 64 * 1024) throw ApiFailure.rejected;
    bytes.add(chunk);
  }
  try {
    return accountSignatureRejected(jsonDecode(utf8.decode(bytes.takeBytes())));
  } catch (_) {
    return false;
  }
}

/// Narrow SDK media endpoint; arbitrary URLs cannot enter the account transport.
extension AccountRecordingStream on AccountApi {
  Future<Response<ResponseBody>> openRecordingContent(
    String callId, {
    required CancelToken cancellation,
    int offset = 0,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(callId) || offset < 0) {
      throw ApiFailure.invalidResponse;
    }
    final initial = _session.credentials;
    if (initial == null) throw ApiFailure.signedOut;
    if (_owner == null || !_owner.sameLogin(initial)) {
      throw ApiFailure.sessionChanged;
    }
    final uri = _uri(
      'api/realtime-translation-calls/$callId/recording-content',
    );
    Future<Response<Object?>> send(AccountCredentials credential) => _send(
      uri,
      credential,
      'GET',
      null,
      null,
      true,
      responseType: ResponseType.stream,
      transport: _binaryClient,
      cancelToken: cancellation,
      contentHeaders: {
        'Accept-Encoding': 'identity',
        if (offset > 0) 'Range': 'bytes=$offset-',
      },
    );
    ResponseBody? opened;
    try {
      var response = await send(initial);
      opened = response.data is ResponseBody
          ? response.data as ResponseBody
          : null;
      _assertCurrent(initial);
      if (response.statusCode == 401) {
        opened =
            null; // The helper owns consumption/cancellation of this stream.
        final rejected = await _streamSignatureRejected(response.data);
        if (rejected) throw ApiFailure.rejected;
        final refreshed = await _refresh(initial);
        _assertCurrent(initial);
        if (cancellation.isCancelled) throw ApiFailure.network;
        response = await send(refreshed);
        opened = response.data is ResponseBody
            ? response.data as ResponseBody
            : null;
        _assertCurrent(initial);
      }
      if (response.statusCode == 401) throw ApiFailure.signedOut;
      if (!const {200, 206, 416}.contains(response.statusCode)) {
        throw ApiFailure.rejected;
      }
      if (opened == null) throw ApiFailure.invalidResponse;
      return Response<ResponseBody>(
        data: opened,
        statusCode: response.statusCode,
        headers: response.headers,
        requestOptions: response.requestOptions,
      );
    } catch (_) {
      await opened?.stream.listen((_) {}).cancel();
      rethrow;
    }
  }
}
