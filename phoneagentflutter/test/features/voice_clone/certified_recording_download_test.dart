import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_certified_recording_download.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_codec.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import '../../support/synthetic_account_api.dart';

class _BinaryApi extends SyntheticAccountApi {
  Uint8List bytes = Uint8List.fromList([82, 73, 70, 70, 1]);
  String mediaType = 'audio/wav';
  bool unauthorized = false, switchAccount = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (request.path.endsWith('/refresh')) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'data': {'voiceCloneAccessToken': 'refreshed'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (switchAccount) {
      credentials = const AccountCredentials('another', 'other', 2);
    }
    if (unauthorized &&
        request.headers['Authorization'] == 'Bearer synthetic') {
      return ResponseBody.fromBytes([0], 401);
    }
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: [mediaType],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }
}

CloneRecordingGrant _grant({String attempt = 'attempt-1', DateTime? expiry}) =>
    CloneRecordingGrant(
      attemptId: attempt,
      grant: 'synthetic+grant/with=query',
      receipt: 'synthetic',
      audioSha256: 'a' * 64,
      personFingerprint: 'synthetic',
      scriptVersion: 'test',
      expiresAt: expiry ?? DateTime.utc(2030),
    );

void main() {
  late _BinaryApi http;
  late ApiCertifiedRecordingDownload download;
  setUp(() {
    http = _BinaryApi();
    download = ApiCertifiedRecordingDownload(
      http.api,
      now: () => DateTime.utc(2026),
    );
  });
  tearDown(() => http.api.close());
  test(
    'fixed same-origin binary endpoint and encoded grant use protected GET',
    () async {
      expect(await download.download(_grant()), http.bytes);
      final request = http.requests.single;
      expect(request.uri.host, 'example.test');
      expect(
        request.uri.path,
        '/api/account/settings/voice-clone/verification/attempt-1/certified-recording',
      );
      expect(request.uri.queryParameters, {
        'grant': 'synthetic+grant/with=query',
      });
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.followRedirects, false);
      expect(request.data, isNull);
    },
  );
  test('401 preserves grant and account while refreshing token once', () async {
    http.unauthorized = true;
    expect(await download.download(_grant()), http.bytes);
    final gets = http.requests.where((r) => r.method == 'GET').toList();
    expect(gets, hasLength(2));
    expect(gets.first.uri, gets.last.uri);
    expect(gets.last.headers['Authorization'], 'Bearer refreshed');
    expect(http.requests, hasLength(3));
  });
  test('expired grant and invalid attempt send nothing', () async {
    for (final grant in [
      _grant(expiry: DateTime.utc(2026)),
      _grant(attempt: '../other'),
    ]) {
      await expectLater(
        Future.sync(() => download.download(grant)),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    expect(http.requests, isEmpty);
  });
  test('oversized binary body cannot reach storage', () async {
    http.bytes = Uint8List(CertifiedRecordingCodec.maxAudioBytes + 1);
    await expectLater(
      download.download(_grant()),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test('non-audio and redirects rejected rather than followed', () async {
    http.mediaType = 'text/html';
    await expectLater(
      download.download(_grant()),
      throwsA(ApiFailure.invalidResponse),
    );
    http.status = 302;
    await expectLater(
      download.download(_grant()),
      throwsA(ApiFailure.rejected),
    );
    expect(http.requests, hasLength(2));
  });
  test('account change during binary request rejects bytes', () async {
    http.switchAccount = true;
    await expectLater(
      download.download(_grant()),
      throwsA(ApiFailure.sessionChanged),
    );
  });
}
