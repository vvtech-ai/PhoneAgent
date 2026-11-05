import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/data/recording_file_downloader.dart';
import 'package:phone_agent/features/translation_history/data/recording_source_resolver.dart';

void main() {
  late Directory root;
  late _Adapter adapter;
  late RecordingFileDownloader files;
  var current = true;
  final bytes = List<int>.generate(64, (i) => i);
  late RecordingDownloadSource source;
  RecordingFileDownloader create([String scope = 'dev/api/account/call']) =>
      RecordingFileDownloader(
        root: root,
        scope: scope,
        isCurrent: () => current,
        client: Dio()..httpClientAdapter = adapter,
      );
  ResponseBody body(
    List<int> value, [
    int status = 200,
    Map<String, List<String>> headers = const {},
  ]) => ResponseBody.fromBytes(value, status, headers: headers);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recording-synthetic-');
    source = RecordingDownloadSource(
      url: Uri.parse('https://synthetic.invalid/file'),
      cacheKey: '../not-a-path',
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      fileName: 'synthetic.m4a',
    );
    current = true;
    adapter = _Adapter((_) async => body(bytes));
    files = create();
  });
  tearDown(() async {
    files.close();
    await root.delete(recursive: true);
  });
  test(
    'domestic content uses authenticated port rather than raw asset client',
    () async {
      final cancellations = <CancelToken>[];
      final authenticated = RecordingFileDownloader(
        root: root,
        scope: 'domestic',
        isCurrent: () => current,
        client: Dio()..httpClientAdapter = adapter,
        openDomestic: (id, offset, cancellation) async {
          expect(id, 'sdk-call');
          expect(offset, 0);
          cancellations.add(cancellation);
          return Response<ResponseBody>(
            data: body(bytes),
            statusCode: 200,
            requestOptions: RequestOptions(path: 'recording-content'),
          );
        },
      );
      final domestic = RecordingDownloadSource(
        url: Uri.parse(
          'https://sdk.invalid/api/realtime-translation-calls/sdk-call/recording-content',
        ),
        cacheKey: source.cacheKey,
        size: source.size,
        sha256: source.sha256,
        fileName: source.fileName,
        accountCallId: 'sdk-call',
      );
      final asset = await authenticated.load(domestic, retry: false);
      expect(await File(asset.localPath).readAsBytes(), bytes);
      expect(adapter.requests, isEmpty);
      authenticated.close();
      expect(cancellations.single.isCancelled, true);
      await expectLater(files.load(domestic, retry: false), throwsStateError);
      expect(adapter.requests, isEmpty);
    },
  );
  test('verified cache rechecks hash, never persists signed locator', () async {
    final asset = await files.load(source, retry: false);
    expect(await File(asset.localPath).readAsBytes(), bytes);
    expect(asset.sha256, source.sha256);
    expect(asset.size, bytes.length);
    await files.load(source, retry: false);
    expect(adapter.requests.length, 1);
    expect(adapter.requests.single.followRedirects, false);
    await File(asset.localPath).writeAsBytes(List.filled(64, 0));
    await files.load(source, retry: false);
    expect(adapter.requests.length, 2);
    expect(await root.list().length, 1);
  });
  test('explicit retry bypasses verified cache', () async {
    await files.load(source, retry: false);
    await files.load(source, retry: true);
    expect(adapter.requests.length, 2);
  });
  test(
    'scope separates accounts even with identical server cache keys',
    () async {
      final first = await files.load(source, retry: false);
      final other = create('dev/api/other-account/call');
      addTearDown(other.close);
      final second = await other.load(source, retry: false);
      expect(second.localPath, isNot(first.localPath));
      expect(adapter.requests.length, 2);
    },
  );
  test('concurrent repositories serialize the same disk asset', () async {
    final other = create();
    addTearDown(other.close);
    final values = await Future.wait([
      files.load(source, retry: false),
      other.load(source, retry: false),
    ]);
    expect(values.first.localPath, values.last.localPath);
    expect(adapter.requests.length, 1);
  });
  test('short response resumes at exact offset with validated 206', () async {
    adapter.respond = (_) async => body(bytes.sublist(0, 12));
    await expectLater(files.load(source, retry: false), throwsStateError);
    adapter.respond = (request) async {
      expect(request.headers['Range'], 'bytes=12-');
      return body(bytes.sublist(12), 206, {
        'content-range': ['bytes 12-63/64'],
      });
    };
    final asset = await files.load(source, retry: false);
    expect(await File(asset.localPath).readAsBytes(), bytes);
  });
  test(
    'server ignoring Range replaces partial rather than appending',
    () async {
      adapter.respond = (_) async => body(bytes.sublist(0, 12));
      await expectLater(files.load(source, retry: false), throwsStateError);
      adapter.respond = (_) async => body(bytes);
      expect(
        await File((await files.load(source, retry: false)).localPath).length(),
        64,
      );
    },
  );
  test('416 clears partial and retries full only once', () async {
    adapter.respond = (_) async => body(bytes.sublist(0, 12));
    await expectLater(files.load(source, retry: false), throwsStateError);
    adapter.respond = (request) async =>
        request.headers.containsKey('Range') ? body([], 416) : body(bytes);
    await files.load(source, retry: false);
    expect(adapter.requests.length, 3);
    expect(adapter.requests.last.headers.containsKey('Range'), false);
  });
  for (final range in [
    'bytes 0-63/64',
    'bytes 12-62/64',
    'bytes 12-63/65',
    'broken',
  ]) {
    test('rejects mismatched partial range $range', () async {
      adapter.respond = (_) async => body(bytes.sublist(0, 12));
      await expectLater(files.load(source, retry: false), throwsStateError);
      adapter.respond = (_) async => body(bytes.sublist(12), 206, {
        'content-range': [range],
      });
      await expectLater(
        files.load(source, retry: false),
        throwsFormatException,
      );
      expect(await root.list().length, 0);
    });
  }
  test('oversized response and invalid checksum never publish', () async {
    adapter.respond = (_) async => body([...bytes, 1]);
    await expectLater(files.load(source, retry: false), throwsFormatException);
    expect(await root.list().length, 0);
    adapter.respond = (_) async => body(List.filled(64, 0));
    await expectLater(files.load(source, retry: false), throwsFormatException);
    expect(await root.list().length, 0);
  });
  test('rejects redirects instead of forwarding identity', () async {
    adapter.respond = (_) async => body([], 302, {
      'location': ['https://other.invalid'],
    });
    await expectLater(files.load(source, retry: false), throwsStateError);
    expect(adapter.requests.length, 1);
    expect(await root.list().length, 0);
  });
  test('owner loss after request prevents publishing', () async {
    adapter.respond = (_) async {
      current = false;
      return body(bytes);
    };
    await expectLater(files.load(source, retry: false), throwsStateError);
    expect(await root.list().length, 0);
  });
  test('close prevents new work', () async {
    files.close();
    await expectLater(files.load(source, retry: false), throwsStateError);
    expect(adapter.requests, isEmpty);
  });
  test('invalidates only the matching scope files', () async {
    final asset = await files.load(source, retry: false);
    final other = create('another-account');
    addTearDown(other.close);
    final otherAsset = await other.load(source, retry: false);
    await files.invalidate(source);
    expect(await File(asset.localPath).exists(), false);
    expect(await File(otherAsset.localPath).exists(), true);
  });
  test(
    'complete verified partial is published without downloading again',
    () async {
      final asset = await files.load(source, retry: false);
      await File(asset.localPath).rename('${asset.localPath}.part');
      await files.load(source, retry: false);
      expect(adapter.requests.length, 1);
      expect(await File(asset.localPath).exists(), true);
    },
  );
  test('Content-Length mismatch is rejected before writing', () async {
    adapter.respond = (_) async => body(bytes, 200, {
      'content-length': ['65'],
    });
    await expectLater(files.load(source, retry: false), throwsFormatException);
    expect(await root.list().length, 0);
  });
  test('second 416 stops instead of looping', () async {
    adapter.respond = (_) async => body(bytes.sublist(0, 12));
    await expectLater(files.load(source, retry: false), throwsStateError);
    adapter.respond = (_) async => body([], 416);
    await expectLater(files.load(source, retry: false), throwsStateError);
    expect(adapter.requests.length, 3);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
