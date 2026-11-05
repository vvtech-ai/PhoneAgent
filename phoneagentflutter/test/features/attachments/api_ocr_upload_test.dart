import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:phone_agent/features/attachments/data/ocr_object_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/attachments/data/api_ocr_attachment_repository.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'ocr_test_support.dart';

void main() {
  late OcrTestSession session;
  late OcrTestAdapter adapter;
  late AccountApi api;
  late OcrTestAdapter objects;
  late ApiOcrAttachmentRepository repository;
  setUp(() {
    session = OcrTestSession();
    adapter = OcrTestAdapter()
      ..respond = (r) =>
          ocrJson(r.path.endsWith('upload-intents') ? grant() : ocrPayload());
    objects = OcrTestAdapter()
      ..respond = (_) => ResponseBody.fromString('', 200);
    api = ocrTestApi(session, adapter);
    repository = ApiOcrAttachmentRepository(
      api,
      uploader: OcrObjectUploader(client: Dio()..httpClientAdapter = objects),
    );
  });
  tearDown(() => api.close());
  test(
    'intent and complete preserve identity; object PUT has no credentials',
    () async {
      final result = await repository.upload(ocrUpload());
      expect(adapter.requests.length, 2);
      final prepare = adapter.requests.first;
      expect(prepare.path, endsWith('/ocr-images/upload-intents'));
      expect(prepare.headers['Authorization'], 'Bearer old');
      final body = jsonDecode(utf8.decode(adapter.bodies.first)) as Map;
      expect(body['attachmentId'], ocrTestId);
      expect(body['checksumSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(body['fileName'], 'synthetic.png');
      expect(objects.requests.single.method, 'PUT');
      expect(
        objects.requests.single.headers.containsKey('Authorization'),
        false,
      );
      expect(
        objects.requests.single.headers.containsKey('X-Account-Id'),
        false,
      );
      expect(objects.bodies.single, ocrTestBytes);
      final commit = jsonDecode(utf8.decode(adapter.bodies.last)) as Map;
      expect(commit['uploadId'], 'synthetic-upload');
      expect(
        commit['metadata']['idempotencyKey'],
        'ocr:$ocrTestSession:$ocrTestId',
      );
      expect(result.sequence, 9);
    },
  );
  test('ambiguous complete retries same upload without another PUT', () async {
    var fail = true;
    adapter.respond = (r) {
      if (r.path.endsWith('upload-intents')) return ocrJson(grant());
      if (fail) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      }
      return ocrJson(ocrPayload());
    };
    await expectLater(
      repository.upload(ocrUpload()),
      throwsA(ApiFailure.network),
    );
    fail = false;
    await repository.upload(ocrUpload());
    expect(objects.requests.length, 1);
    expect(
      adapter.requests.where((r) => r.path.endsWith('upload-intents')).length,
      1,
    );
    expect(adapter.bodies[1], adapter.bodies[2]);
  });
  test('failed object PUT never calls complete', () async {
    objects.respond = (_) => ResponseBody.fromString('', 500);
    await expectLater(
      repository.upload(ocrUpload()),
      throwsA(ApiFailure.rejected),
    );
    expect(adapter.requests.length, 1);
  });
  for (final status in [200, 422, 502]) {
    test('refinement error is distinguished for status $status', () async {
      adapter.respond = (_) =>
          ocrJson(null, status: status, error: 'OCR_AI_REFINEMENT_FAILED');
      await expectLater(
        repository.upload(ocrUpload()),
        throwsA(
          isA<OcrCommitFailure>().having(
            (e) => e.reason,
            'reason',
            OcrFailure.refinement,
          ),
        ),
      );
      expect(adapter.requests.length, 1);
    });
  }
  test(
    'arbitrary error body is not exposed or automatically replayed',
    () async {
      adapter.respond = (_) =>
          ocrJson(null, status: 500, error: 'private synthetic details');
      await expectLater(
        repository.upload(ocrUpload()),
        throwsA(ApiFailure.rejected),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test('network unknown does not trigger another upload', () async {
    adapter.respond = (r) => throw DioException(
      requestOptions: r,
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      repository.upload(ocrUpload()),
      throwsA(ApiFailure.network),
    );
    expect(adapter.requests.length, 1);
  });
  test(
    'zero, oversized and unsafe identity are rejected before network',
    () async {
      for (final input in [
        ocrUpload(bytes: Uint8List(0)),
        ocrUpload(bytes: Uint8List(ocrMaxImageBytes + 1)),
        ocrUpload(sessionId: '../other'),
      ]) {
        await expectLater(
          repository.upload(input),
          throwsA(isA<OcrCommitFailure>()),
        );
      }
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'mismatched identity, size, anchor or durable receipt fail closed',
    () async {
      for (final change in <Map<String, Object?>>[
        {'sessionId': 'other'},
        {'attachmentId': 'ocr-other'},
        {'fileSize': 7},
        {'anchorStepCount': 0},
        {'createdOrdinal': 4},
        {'eventId': ''},
        {'sequence': 0},
        {'fullText': ''},
        {
          'fields': [
            {'label': 'bad'},
          ],
        },
      ]) {
        adapter.respond = (r) => ocrJson(
          r.path.endsWith('upload-intents')
              ? grant()
              : {...ocrPayload(), ...change},
        );
        await expectLater(
          repository.upload(ocrUpload()),
          throwsA(isA<OcrCommitFailure>()),
        );
      }
    },
  );
  test(
    'account changes before or during upload never return old success',
    () async {
      adapter.respond = (_) {
        session.credentials = const AccountCredentials('other', 'other', 2);
        return ocrJson(ocrPayload());
      };
      await expectLater(
        repository.upload(ocrUpload()),
        throwsA(ApiFailure.sessionChanged),
      );
      await expectLater(
        repository.upload(ocrUpload()),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests.length, 1);
    },
  );
}

Map<String, Object?> grant() => {
  'uploadId': 'synthetic-upload',
  'uploadUrl': 'https://objects.example.test/file?signature=synthetic',
  'contentType': 'image/png',
  'expiresAt': '2099-01-01T00:00:00Z',
};
