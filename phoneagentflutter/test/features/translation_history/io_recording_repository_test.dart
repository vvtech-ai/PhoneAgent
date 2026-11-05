import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/data/io_recording_repository.dart';
import 'package:phone_agent/features/translation_history/data/recording_file_downloader.dart';
import 'package:phone_agent/features/translation_history/data/recording_source_resolver.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  late _Resolver resolver;
  late _Files files;
  late IoRecordingRepository repository;
  setUp(() {
    resolver = _Resolver();
    files = _Files();
    repository = IoRecordingRepository(resolver, () async => files);
  });
  tearDown(() => repository.close());
  test(
    'load resolves fresh credentials, explicit retry invalidates previous asset before refresh',
    () async {
      await repository.load(retry: false, processing: () {});
      resolver.onResolve = () {
        expect(files.invalidated, [resolver.source]);
      };
      await repository.load(retry: true, processing: () {});
      expect(resolver.loads, 2);
      expect(files.retries, [false, true]);
    },
  );
  test('close cancels resolver and file port', () async {
    await repository.load(retry: false, processing: () {});
    repository.close();
    expect(files.closed, true);
    expect(resolver.closed, true);
    await expectLater(
      repository.load(retry: false, processing: () {}),
      throwsStateError,
    );
  });
  test('late cache-root result is closed after page disposal', () async {
    final factory = Completer<RecordingFileDownloader>(),
        started = Completer<void>();
    repository = IoRecordingRepository(resolver, () {
      started.complete();
      return factory.future;
    });
    final load = repository.load(retry: false, processing: () {});
    final expected = expectLater(load, throwsStateError);
    await started.future;
    repository.close();
    factory.complete(files);
    await expected;
    expect(files.closed, true);
    expect(files.retries, isEmpty);
  });
}

class _Resolver extends Fake implements RecordingSourceResolver {
  int loads = 0;
  bool closed = false;
  void Function()? onResolve;
  final source = RecordingDownloadSource(
    url: Uri.parse('https://synthetic.invalid'),
    cacheKey: 'key',
    size: 0,
    sha256: List.filled(64, 'a').join(),
    fileName: 'test.m4a',
  );
  @override
  Future<RecordingDownloadSource> resolve(void Function() processing) async {
    loads++;
    onResolve?.call();
    return source;
  }

  @override
  void close() {
    closed = true;
  }
}

class _Files extends Fake implements RecordingFileDownloader {
  bool closed = false;
  final retries = <bool>[];
  final invalidated = <RecordingDownloadSource>[];
  @override
  Future<RecordingAudioAsset> load(
    RecordingDownloadSource source, {
    required bool retry,
  }) async {
    retries.add(retry);
    return const RecordingAudioAsset('synthetic', 'test.m4a', 'audio/mp4');
  }

  @override
  Future<void> invalidate(RecordingDownloadSource source) async {
    invalidated.add(source);
  }

  @override
  void close() {
    closed = true;
  }
}
