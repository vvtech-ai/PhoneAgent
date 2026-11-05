import 'package:dio/dio.dart';
import '../../../core/config/translation_service_config.dart';
import '../domain/translation_history.dart';

typedef DomesticRecordingOpen =
    Future<Response<ResponseBody>> Function(
      String callId,
      int offset,
      CancelToken cancellation,
    );

class RecordingDownloadSource {
  const RecordingDownloadSource({
    required this.url,
    required this.cacheKey,
    required this.size,
    required this.sha256,
    required this.fileName,
    this.contentType = 'audio/mp4',
    this.headers = const {},
    this.accountCallId,
  });
  final String? accountCallId;
  final Uri url;
  final String cacheKey, sha256, fileName, contentType;
  final int size;
  final Map<String, String> headers;
}

class RecordingSourceResolver {
  RecordingSourceResolver({
    required this.history,
    required this.callId,
    required this.accountId,
    required this.apiBase,
    required this.services,
    required this.isCurrent,
    Dio? client,
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? Dio(),
       _delay = delay ?? Future<void>.delayed {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.json,
    );
  }
  final TranslationHistoryRepository history;
  final String callId, accountId;
  final Uri apiBase;
  final TranslationServiceConfig services;
  final bool Function() isCurrent;
  final Dio _client;
  final Future<void> Function(Duration) _delay;
  final _cancel = CancelToken();
  bool _closed = false;
  void check() {
    if (_closed || !isCurrent()) {
      throw StateError('Recording owner unavailable');
    }
  }

  Future<RecordingDownloadSource> resolve(void Function() processing) async {
    check();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(callId)) {
      throw const FormatException('Invalid recording identity');
    }
    final detail = await history.load(callId);
    check();
    if (detail.callId != callId) {
      throw const FormatException('Recording owner mismatch');
    }
    final recording = detail.recording;
    if (recording == null) throw StateError('Recording unavailable');
    if (recording.source == 'PHONE_AGENT') {
      final raw = recording.contentUrl ?? '';
      // v65 treats /api/... as relative to the configured application context.
      final url = Uri.parse(raw).hasScheme
          ? Uri.parse(raw)
          : apiBase.resolve(raw.replaceFirst(RegExp(r'^/+'), ''));
      // Backend builds this exact path. Reject absolute foreign URLs before adding identity.
      final expected = apiBase.resolve(
        'api/realtime-translation-calls/$callId/recording-content',
      );
      if (url != expected ||
          accountId.isEmpty ||
          accountId.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('Invalid recording endpoint');
      }
      return _validated(
        url: url,
        key: recording.cacheKey,
        size: recording.sizeBytes,
        checksum: recording.checksum,
        name: recording.fileName,
        headers: {'X-Account-Id': accountId},
        accountCallId: callId,
      );
    }
    if (recording.source != 'WORLD_CALL') {
      throw const FormatException('Invalid recording source');
    }
    final cluster = recording.clusterId?.trim().toUpperCase();
    final session = recording.callSessionId ?? '',
        grant = recording.accessGrant ?? '';
    if (!const {'US', 'JP'}.contains(cluster) ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(session) ||
        grant.isEmpty ||
        grant.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid recording locator');
    }
    final endpoint = services
        .resolve(cluster!)
        .resolve('api/app-translation-calls/$session/recording/play-token');
    var waited = 0;
    while (true) {
      check();
      final response = await _client.postUri<Object?>(
        endpoint,
        data: '',
        options: Options(headers: {'Authorization': 'Bearer $grant'}),
        cancelToken: _cancel,
      );
      check();
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Invalid recording response');
      }
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        final raw = data['url'];
        final url = raw is String ? Uri.tryParse(raw) : null;
        if (url == null ||
            url.scheme != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty ||
            url.hasFragment) {
          throw const FormatException('Invalid recording download');
        }
        return _validated(
          url: url,
          key: data['cacheKey'],
          size: data['sizeBytes'],
          checksum: data['checksumSha256'],
          name: recording.fileName,
          type: data['contentType'] is String
              ? data['contentType'] as String
              : 'audio/mp4',
        );
      }
      if (data['code'] != 'RECORDING_NOT_READY') {
        throw StateError('Recording unavailable');
      }
      final rawRetry = data['retryAfterMillis'];
      final retry = rawRetry is int && rawRetry > 0 ? rawRetry : 1000;
      if (waited + retry > 120000) {
        throw StateError('Recording processing timeout');
      }
      processing();
      await _delay(Duration(milliseconds: retry));
      waited += retry;
    }
  }

  static RecordingDownloadSource _validated({
    required Uri url,
    required Object? key,
    required Object? size,
    required Object? checksum,
    required String name,
    String type = 'audio/mp4',
    Map<String, String> headers = const {},
    String? accountCallId,
  }) {
    if (key is! String ||
        key.trim().isEmpty ||
        size is! int ||
        size < 0 ||
        checksum is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      throw const FormatException('Invalid recording integrity');
    }
    final safeName = name.replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_').trim();
    return RecordingDownloadSource(
      url: url,
      cacheKey: key,
      size: size,
      sha256: checksum.toLowerCase(),
      fileName: safeName.isEmpty ? 'realtime-translation.m4a' : safeName,
      contentType: type.isEmpty ? 'audio/mp4' : type,
      headers: headers,
      accountCallId: accountCallId,
    );
  }

  void close() {
    _closed = true;
    _cancel.cancel();
    _client.close(force: true);
  }
}
