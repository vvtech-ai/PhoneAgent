import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/attachments/data/api_ocr_attachment_repository.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'ocr_test_support.dart';

void main() {
  late OcrTestSession session;
  late OcrTestAdapter adapter;
  late AccountApi api;
  late ApiOcrAttachmentRepository repository;
  final item = PersistedOcrAttachment.fromPayload(ocrTestSession, ocrPayload());
  setUp(() {
    session = OcrTestSession();
    adapter = OcrTestAdapter()..respond = (_) => ocrBinary();
    api = ocrTestApi(session, adapter);
    repository = ApiOcrAttachmentRepository(api);
  });
  tearDown(() => api.close());
  test(
    '401 cancels its still-open body before replay with a fresh token',
    () async {
      final cancelled = Completer<void>();
      final denied = StreamController<Uint8List>(
        onCancel: () {
          cancelled.complete();
        },
      );
      adapter.respond = (r) {
        if (r.path.endsWith('/refresh')) {
          return ocrJson({'voiceCloneAccessToken': 'new'});
        }
        return r.headers['Authorization'] == 'Bearer old'
            ? ocrBinary(status: 401, stream: denied.stream)
            : ocrBinary();
      };
      expect(await repository.loadImage(item), ocrTestBytes);
      await cancelled.future.timeout(const Duration(seconds: 2));
      expect(adapter.requests.first.cancelToken!.isCancelled, isTrue);
      expect(
        identical(
          adapter.requests.first.cancelToken,
          adapter.requests.last.cancelToken,
        ),
        isFalse,
      );
      await denied.close();
    },
  );
  test(
    'binary attachment uses same origin/account, preserves chunks and closes request',
    () async {
      adapter.respond = (_) => ocrBinary(
        length: 8,
        stream: Stream.fromIterable([
          Uint8List.sublistView(ocrTestBytes, 0, 3),
          Uint8List.sublistView(ocrTestBytes, 3),
        ]),
      );
      expect(await repository.loadImage(item), ocrTestBytes);
      final r = adapter.requests.single;
      expect(r.uri.toString(), 'https://example.test/prefix/${item.path}');
      expect(r.headers['X-Account-Id'], 'synthetic-account');
      expect(r.headers['Authorization'], 'Bearer old');
      expect(r.followRedirects, false);
      expect(r.cancelToken!.isCancelled, isTrue);
    },
  );
  test(
    'binary 401 refresh succeeds once; repeated 401 has bounded retry',
    () async {
      var alwaysReject = false;
      adapter.respond = (r) => r.path.endsWith('/refresh')
          ? ocrJson({'voiceCloneAccessToken': 'new'})
          : ocrBinary(
              status: alwaysReject || r.headers['Authorization'] == 'Bearer old'
                  ? 401
                  : 200,
            );
      expect(await repository.loadImage(item), ocrTestBytes);
      expect(adapter.requests.length, 3);
      alwaysReject = true;
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.signedOut),
      );
      expect(adapter.requests.length, 6);
    },
  );
  test(
    'invalid content type, empty and truncated bytes are not a valid image',
    () async {
      for (final response in [
        ocrBinary(type: 'text/html'),
        ocrBinary(length: 9),
        ocrBinary(stream: Stream.value(Uint8List(0))),
        ocrBinary(stream: Stream.value(Uint8List(7))),
        ocrBinary(length: 7),
      ]) {
        adapter.respond = (_) => response;
        await expectLater(
          repository.loadImage(item),
          throwsA(ApiFailure.invalidResponse),
        );
        expect(adapter.requests.last.cancelToken!.isCancelled, isTrue);
      }
    },
  );
  test(
    'undeclared oversized stream is cut off before remaining chunks',
    () async {
      var delivered = 0, closed = false;
      Stream<Uint8List> source() async* {
        try {
          for (var n = 0; n < 10; n++) {
            delivered++;
            yield Uint8List(40 * 1024);
          }
        } finally {
          closed = true;
        }
      }

      adapter.respond = (_) => ocrBinary(stream: source());
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(delivered, lessThan(10));
      expect(closed, isTrue);
      expect(adapter.requests.single.cancelToken!.isCancelled, isTrue);
    },
  );
  test(
    'account change during chunks drops bytes instead of giving old image to new account',
    () async {
      Stream<Uint8List> source() async* {
        yield Uint8List(4);
        session.credentials = const AccountCredentials('other', 'other', 2);
        yield Uint8List(4);
      }

      adapter.respond = (_) => ocrBinary(stream: source());
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test(
    'account change while refreshing prevents replay under new login',
    () async {
      adapter.respond = (r) {
        if (r.path.endsWith('/refresh')) {
          session.credentials = const AccountCredentials('other', 'other', 2);
          return ocrJson({'voiceCloneAccessToken': 'new'});
        }
        return ocrBinary(status: 401);
      };
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'same account logged in again cannot reuse prior repository credentials',
    () async {
      session.credentials = const AccountCredentials(
        'synthetic-account',
        'new',
        2,
      );
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test('redirect and server error are not followed or retried', () async {
    for (final status in [302, 403, 404, 500]) {
      adapter.respond = (_) => ocrBinary(status: status);
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.rejected),
      );
    }
    expect(adapter.requests.length, 4);
  });
  test(
    'invalid/download foreign paths reject before sending credentials',
    () async {
      for (final path in [
        'https://other.test/image',
        'api/../image',
        'api/a?token=x',
      ]) {
        await expectLater(
          api.download(path, maxBytes: 8, mediaTypes: {'image/png'}),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'timeout on body becomes network failure without automatic read retry',
    () async {
      adapter.respond = (_) =>
          ocrBinary(stream: Stream.error(TimeoutException('synthetic')));
      await expectLater(
        repository.loadImage(item),
        throwsA(ApiFailure.network),
      );
      expect(adapter.requests.length, 1);
    },
  );
}
