import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/conversation/data/api_call_recording_repository.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18);
  const base = 'https://example.test/aiassistant-api/';
  final token = 'a' * 32;
  final path = 'api/agent-calls/recording-content/$token';
  late SyntheticAccountApi wire;
  late AccountApi api;
  late ApiCallRecordingRepository repository;
  var current = true;
  ApiCallRecordingRepository create({String callId = 'call-1'}) =>
      ApiCallRecordingRepository(
        api: api,
        apiBase: Uri.parse(base),
        callId: callId,
        isCurrent: () => current,
        now: () => now,
      );
  Map<String, Object?> source() => {
    'url': '/$path',
    'contentType': 'audio/wav',
    'sizeBytes': 24,
    'expiresAt': now.add(const Duration(minutes: 5)).toIso8601String(),
  };
  setUp(() {
    wire = SyntheticAccountApi();
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: base),
      wire,
      client: Dio()..httpClientAdapter = wire,
    );
    current = true;
    repository = create();
  });
  tearDown(() {
    repository.close();
    api.close();
    wire.api.close();
  });
  Future<dynamic> load() => repository.load(retry: false, processing: () {});

  test(
    'metadata is account-bound GET only, not a token or content download',
    () async {
      wire.data = {
        'callId': 'call-1',
        'status': 'PROCESSING',
        'durationMillis': 12000,
        'sizeBytes': null,
      };
      final info = await repository.metadata();
      expect(info.processing, true);
      expect(info.durationMillis, 12000);
      final request = wire.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.toString(), '${base}api/agent-calls/call-1/recording');
      expect(request.headers['X-Account-Id'], 'a');
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.followRedirects, false);
    },
  );
  test(
    'fresh POST each start, preserves API context, optional size not invented hash',
    () async {
      wire.data = source();
      final asset = await load();
      expect(asset.remoteUri.toString(), '$base$path');
      expect(asset.size, 24);
      expect(asset.sha256, null);
      expect(() => asset.localPath, throwsStateError);
      await load();
      expect(wire.requests, hasLength(2));
      expect(wire.requests.every((r) => r.method == 'POST'), true);
      expect(
        wire.requests.last.uri.path,
        '/aiassistant-api/api/agent-calls/call-1/recording/play-token',
      );
      expect(wire.requests.last.headers['X-Account-Id'], 'a');
      expect(wire.requests.last.headers['Authorization'], 'Bearer synthetic');
    },
  );
  test(
    'old minimal response accepted, same-context absolute URL supported',
    () async {
      wire.data = {'url': '$base$path'};
      final asset = await load();
      expect(asset.size, null);
      expect(asset.contentType, 'audio/wav');
      expect(asset.remoteUri.toString(), '$base$path');
    },
  );
  test(
    'rejects foreign or malformed content source without requesting it',
    () async {
      for (final url in [
        'https://other.test/$path',
        'http://example.test/aiassistant-api/$path',
        'https://example.test/$path',
        'https://user@example.test/aiassistant-api/$path',
        '//$path',
        '/$path?secret=1',
        '/$path#fragment',
        '/api/agent-calls/recording-content/../$token',
        '/api/agent-calls/recording-content/%61${'a' * 31}',
        '/api/agent-calls/call-1/recording',
        '',
      ]) {
        wire.data = {...source(), 'url': url};
        await expectLater(load(), throwsA(ApiFailure.invalidResponse));
      }
      expect(
        wire.requests.every((r) => r.uri.path.endsWith('/play-token')),
        true,
      );
    },
  );
  test(
    'expires and type/size validation does not expose server text',
    () async {
      for (final patch in [
        {'expiresAt': now.toIso8601String()},
        {'expiresAt': 'invalid'},
        {'sizeBytes': -1},
        {'sizeBytes': 0},
        {'sizeBytes': '24'},
        {'contentType': 'text/html'},
        {'contentType': 'audio/wav\r\nsecret'},
      ]) {
        wire.data = {...source(), ...patch};
        await expectLater(load(), throwsA(ApiFailure.invalidResponse));
      }
    },
  );
  test(
    'wrong call or malformed metadata rejected; missing legacy remains readable',
    () async {
      for (final data in [
        {'callId': 'other', 'status': 'READY'},
        {'callId': 'call-1', 'status': ''},
        {'callId': 'call-1', 'status': 'READY', 'durationMillis': -1},
      ]) {
        wire.data = data;
        await expectLater(
          repository.metadata(),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      wire.data = {'callId': 'call-1', 'status': 'LEGACY_MISSING'};
      final info = await repository.metadata();
      expect(info.processing, false);
      expect(info.durationMillis, null);
    },
  );
  test('invalid call fails before transport', () async {
    final invalid = create(callId: '../other');
    await expectLater(invalid.metadata(), throwsA(ApiFailure.invalidResponse));
    expect(wire.requests, isEmpty);
    invalid.close();
  });
  test(
    'close and owner change reject work but do not close shared API',
    () async {
      repository.close();
      await expectLater(load(), throwsA(ApiFailure.sessionChanged));
      repository = create();
      current = false;
      await expectLater(
        repository.metadata(),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(wire.requests, isEmpty);
      wire.data = {};
      await api.request('api/other');
      expect(wire.requests, hasLength(1));
    },
  );
  test('owner change after response start drops playback source', () async {
    wire.data = source();
    final future = load();
    current = false;
    await expectLater(future, throwsA(ApiFailure.sessionChanged));
  });
}
