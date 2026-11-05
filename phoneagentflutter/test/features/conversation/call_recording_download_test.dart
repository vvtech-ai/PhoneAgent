import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/call_recording_file_download.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  late Directory directory;
  late _Wire wire;
  late CallRecordingFileDownload download;
  var current = true;
  RecordingAudioAsset source({
    int? size = 8,
    String? url,
  }) => RecordingAudioAsset.remote(
    Uri.parse(
      url ??
          'https://example.test/app/api/agent-calls/recording-content/${'a' * 32}',
    ),
    'sample.m4a',
    'audio/wav',
    size: size,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('synthetic-recording-');
    wire = _Wire();
    current = true;
    download = CallRecordingFileDownload(
      root: () async => directory.path,
      apiBase: Uri.parse('https://example.test/app/'),
      scope: 'synthetic-account/call',
      isCurrent: () => current,
      maxBytes: 32,
      client: Dio()..httpClientAdapter = wire,
    );
  });
  tearDown(() async {
    download.close();
    await directory.delete(recursive: true);
  });
  test(
    'streams private file, computes local digest, no credentials or redirects',
    () async {
      final asset = await download.download(source());
      expect(
        await File(asset.localPath).readAsBytes(),
        utf8.encode('12345678'),
      );
      expect(
        asset.sha256,
        crypto.sha256.convert(utf8.encode('12345678')).toString(),
      );
      expect(asset.size, 8);
      expect(wire.request!.followRedirects, false);
      expect(
        wire.request!.headers.keys.any(
          (key) =>
              key.toLowerCase() == 'authorization' ||
              key.toLowerCase() == 'x-account-id',
        ),
        false,
      );
      await download.remove(asset);
      expect(await directory.list().toList(), isEmpty);
    },
  );
  test('missing server size accepted; cannot delete unrelated files', () async {
    final asset = await download.download(source(size: null));
    expect(asset.size, 8);
    await expectLater(
      download.remove(const RecordingAudioAsset('/unowned', 'x', 'audio/wav')),
      throwsStateError,
    );
    expect(await File(asset.localPath).exists(), true);
  });
  test(
    'bad status, MIME, length, truncation and overflow clean this file',
    () async {
      for (final configure in <void Function()>[
        () => wire.status = 302,
        () => wire.type = 'text/html',
        () => wire.length = '100',
        () => wire.length = '9',
        () => wire.bytes = utf8.encode('short'),
        () => wire.bytes = List.filled(40, 0),
      ]) {
        wire.reset();
        configure();
        await expectLater(download.download(source()), throwsA(anything));
        expect(await directory.list().toList(), isEmpty);
      }
    },
  );
  test(
    'foreign source rejected before transport, account change stops work',
    () async {
      await expectLater(
        download.download(source(url: 'https://other.test/audio')),
        throwsFormatException,
      );
      expect(wire.request, null);
      current = false;
      await expectLater(download.download(source()), throwsStateError);
      expect(await directory.list().toList(), isEmpty);
    },
  );
  test(
    'separate saves never reuse an expired token file or staging identity',
    () async {
      final first = await download.download(source());
      final second = await download.download(source());
      expect(first.localPath, isNot(second.localPath));
      await download.remove(first);
      await download.remove(second);
      expect(await directory.list().toList(), isEmpty);
    },
  );
}

class _Wire implements HttpClientAdapter {
  int status = 200;
  String type = 'audio/wav', length = '8';
  List<int> bytes = utf8.encode('12345678');
  RequestOptions? request;
  void reset() {
    status = 200;
    type = 'audio/wav';
    length = '8';
    bytes = utf8.encode('12345678');
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    return ResponseBody(
      Stream.value(Uint8List.fromList(bytes)),
      status,
      headers: {
        Headers.contentTypeHeader: [type],
        Headers.contentLengthHeader: [length],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
