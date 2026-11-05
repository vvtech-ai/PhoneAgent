import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/api_domestic_recording_uploader.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';
import '../../support/synthetic_account_api.dart';

/// Consume multipart bytes as a real transport does, releasing file handles.
class _UploadApi extends SyntheticAccountApi {
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    await stream?.drain<void>();
    return super.fetch(request, null, cancel);
  }
}

void main() {
  late Directory root;
  late File file;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('upload-offline');
    file = File('${root.path}/recording.m4a');
    await file.writeAsBytes([1, 2, 3]);
  });
  tearDown(() async => root.delete(recursive: true));
  DomesticRecordingAttachment metadata() => DomesticRecordingAttachment(
    durationMillis: 100,
    checksumSha256: sha256.convert([1, 2, 3]).toString(),
  );
  test(
    'native multipart route and confirmed metadata preserve owned file',
    () async {
      final http = _UploadApi();
      addTearDown(http.api.close);
      http.data = {
        'source': 'PHONE_AGENT',
        'contentType': 'audio/mp4',
        'sizeBytes': 3,
        'checksumSha256': metadata().checksumSha256,
      };
      final uploader = ApiDomesticRecordingUploader(
        http.api,
        resolveOwnedFile: (_) async => file,
        isCurrent: () => true,
      );
      await uploader.upload(
        serverCallId: 'synthetic-server',
        clientCallId: 'synthetic-client',
        recording: metadata(),
      );
      final request = http.requests.single;
      expect(request.path, endsWith('/synthetic-server/recording-content'));
      expect(request.method, 'PUT');
      final form = request.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'durationMillis': '100',
        'checksumSha256': metadata().checksumSha256,
      });
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.contentType.toString(), 'audio/mp4');
      expect(await file.exists(), isTrue);
    },
  );
  test(
    'tampered bytes, account loss and unconfirmed server metadata fail without deletion',
    () async {
      final http = _UploadApi();
      addTearDown(http.api.close);
      var current = true;
      final uploader = ApiDomesticRecordingUploader(
        http.api,
        resolveOwnedFile: (_) async => file,
        isCurrent: () => current,
      );
      await file.writeAsBytes([4]);
      await expectLater(
        uploader.upload(
          serverCallId: 'server',
          clientCallId: 'client',
          recording: metadata(),
        ),
        throwsA(anything),
      );
      expect(http.requests, isEmpty);
      await file.writeAsBytes([1, 2, 3]);
      current = false;
      await expectLater(
        uploader.upload(
          serverCallId: 'server',
          clientCallId: 'client',
          recording: metadata(),
        ),
        throwsA(anything),
      );
      expect(http.requests, isEmpty);
      current = true;
      http.data = {
        'source': 'PHONE_AGENT',
        'contentType': 'audio/mp4',
        'sizeBytes': 3,
        'checksumSha256': 'wrong',
      };
      await expectLater(
        uploader.upload(
          serverCallId: 'server',
          clientCallId: 'client',
          recording: metadata(),
        ),
        throwsA(anything),
      );
      expect(await file.exists(), isTrue);
    },
  );
}
