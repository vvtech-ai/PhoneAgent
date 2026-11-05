import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/translation_service_config.dart';
import 'package:phone_agent/features/translation_history/data/recording_source_resolver.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';

void main() {
  late _History history;
  late _Adapter adapter;
  late RecordingSourceResolver resolver;
  final waits = <Duration>[];
  var current = true;
  final digest = List.filled(64, 'a').join();
  Map<String, Object?> ready() => {
    'url': 'https://files.example.test/audio?sig=synthetic',
    'cacheKey': 'synthetic-key',
    'sizeBytes': 8,
    'checksumSha256': digest,
  };
  setUp(() {
    history = _History();
    adapter = _Adapter(ready());
    current = true;
    waits.clear();
    resolver = RecordingSourceResolver(
      history: history,
      callId: 'call-1',
      accountId: 'synthetic-account',
      apiBase: Uri.parse('https://account.example.test/aiassistant-api/'),
      services: const TranslationServiceConfig({
        'US': 'https://us.example.test',
        'JP': 'https://jp.example.test',
      }),
      client: Dio()..httpClientAdapter = adapter,
      isCurrent: () => current,
      delay: (value) async {
        waits.add(value);
      },
    );
  });
  tearDown(() => resolver.close());
  test(
    'world authorization has empty POST body; signed download carries no credentials',
    () async {
      final source = await resolver.resolve(() {});
      expect(history.loads, 1);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        'https://us.example.test/api/app-translation-calls/session-1/recording/play-token',
      );
      expect(adapter.bodies.single, isEmpty);
      expect(request.followRedirects, false);
      expect(request.headers['Authorization'], 'Bearer synthetic-grant');
      expect(request.headers.containsKey('X-Account-Id'), false);
      expect(source.headers, isEmpty);
      expect(source.size, 8);
      expect(source.sha256, digest);
    },
  );
  test('JP explicit region preserves its endpoint', () async {
    history.recording = const TranslationRecording(
      source: 'WORLD_CALL',
      clusterId: 'JP',
      callSessionId: 'session-1',
      accessGrant: 'synthetic-grant',
    );
    await resolver.resolve(() {});
    expect(adapter.requests.single.uri.host, 'jp.example.test');
  });
  test('each resolve refreshes detail and grant', () async {
    await resolver.resolve(() {});
    history.recording = const TranslationRecording(
      source: 'WORLD_CALL',
      clusterId: 'US',
      callSessionId: 'session-1',
      accessGrant: 'synthetic-new-grant',
    );
    await resolver.resolve(() {});
    expect(history.loads, 2);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer synthetic-new-grant',
    );
  });
  test(
    'backend relative recording-content preserves configured application context',
    () async {
      history.recording = TranslationRecording(
        source: 'PHONE_AGENT',
        contentUrl: '/api/realtime-translation-calls/call-1/recording-content',
        cacheKey: 'own-key',
        sizeBytes: 8,
        checksum: digest,
      );
      final source = await resolver.resolve(() {});
      expect(
        source.url.toString(),
        'https://account.example.test/aiassistant-api/api/realtime-translation-calls/call-1/recording-content',
      );
      expect(source.headers, {'X-Account-Id': 'synthetic-account'});
      expect(adapter.requests, isEmpty);
    },
  );
  for (final url in [
    'https://foreign.example.test/api/realtime-translation-calls/call-1/recording-content',
    '/api/realtime-translation-calls/other/recording-content',
    '/api/realtime-translation-calls/call-1/recording-content?extra=true',
    '/api/realtime-translation-calls/call-1/recording/content',
  ]) {
    test('unsafe PHONE_AGENT endpoint rejected: $url', () async {
      history.recording = TranslationRecording(
        source: 'PHONE_AGENT',
        contentUrl: url,
        cacheKey: 'key',
        sizeBytes: 8,
        checksum: digest,
      );
      await expectLater(resolver.resolve(() {}), throwsFormatException);
      expect(adapter.requests, isEmpty);
    });
  }
  test('only RECORDING_NOT_READY retries with server delay', () async {
    adapter.status = 409;
    adapter.data = {'code': 'RECORDING_NOT_READY', 'retryAfterMillis': 12};
    var processing = 0;
    final source = await resolver.resolve(() {
      processing++;
      adapter.status = 200;
      adapter.data = ready();
    });
    expect(processing, 1);
    expect(waits, [const Duration(milliseconds: 12)]);
    expect(adapter.requests.length, 2);
    expect(source.size, 8);
  });
  test('processing stops at cumulative 120 seconds', () async {
    adapter.status = 409;
    adapter.data = {'code': 'RECORDING_NOT_READY', 'retryAfterMillis': 60000};
    await expectLater(resolver.resolve(() {}), throwsStateError);
    expect(waits, hasLength(2));
    expect(adapter.requests, hasLength(3));
  });
  test('missing retry delay defaults to one second', () async {
    adapter.status = 409;
    adapter.data = {'code': 'RECORDING_NOT_READY'};
    await resolver.resolve(() {
      adapter.status = 200;
      adapter.data = ready();
    });
    expect(waits.single, const Duration(seconds: 1));
  });
  test('grant expiration does not loop or expose server message', () async {
    adapter.status = 401;
    adapter.data = {'code': 'EXPIRED', 'message': 'synthetic-secret'};
    await expectLater(
      resolver.resolve(() {}),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              !error.toString().contains('synthetic-secret'),
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
    expect(waits, isEmpty);
  });
  for (final url in [
    'http://files.example.test/a',
    'https://user:password@files.example.test/a',
    'https://files.example.test/a#fragment',
    '/a',
  ]) {
    test('invalid signed download rejected: $url', () async {
      adapter.data = ready()..['url'] = url;
      await expectLater(resolver.resolve(() {}), throwsFormatException);
    });
  }
  for (final entry in {
    'sizeBytes': -1,
    'checksumSha256': 'bad',
    'cacheKey': '',
  }.entries) {
    test('integrity field rejected: ${entry.key}', () async {
      adapter.data = ready()..[entry.key] = entry.value;
      await expectLater(resolver.resolve(() {}), throwsFormatException);
    });
  }
  test('changed account during processing never requests again', () async {
    adapter.status = 409;
    adapter.data = {'code': 'RECORDING_NOT_READY'};
    await expectLater(
      resolver.resolve(() {
        current = false;
      }),
      throwsStateError,
    );
    expect(adapter.requests, hasLength(1));
  });
  test('mismatched detail never requests recording grant', () async {
    history.callId = 'other';
    await expectLater(resolver.resolve(() {}), throwsFormatException);
    expect(adapter.requests, isEmpty);
  });
  test('unknown cluster cannot fall back to default', () async {
    history.recording = const TranslationRecording(
      source: 'WORLD_CALL',
      clusterId: 'OTHER',
      callSessionId: 'session',
      accessGrant: 'grant',
    );
    await expectLater(resolver.resolve(() {}), throwsFormatException);
    expect(adapter.requests, isEmpty);
  });
  test('closed resolver never loads history or creates requests', () async {
    resolver.close();
    await expectLater(resolver.resolve(() {}), throwsStateError);
    expect(history.loads, 0);
  });
}

class _History implements TranslationHistoryRepository {
  int loads = 0;
  String callId = 'call-1';
  TranslationRecording recording = const TranslationRecording(
    source: 'WORLD_CALL',
    clusterId: 'US',
    callSessionId: 'session-1',
    accessGrant: 'synthetic-grant',
  );
  @override
  Future<TranslationHistory> load(String _) async {
    loads++;
    return TranslationHistory(
      callId: callId,
      route: TranslationRoute.worldCall,
      targetName: '',
      phoneNumber: '',
      myLanguage: 'zh',
      peerLanguage: 'en',
      connectedAt: '',
      endedAt: '',
      durationMillis: 0,
      transcripts: const [],
      recording: recording,
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.data);
  Map<String, Object?> data;
  int status = 200;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    bodies.add(
      stream == null
          ? []
          : await stream.fold<List<int>>(
              [],
              (all, chunk) => all..addAll(chunk),
            ),
    );
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
