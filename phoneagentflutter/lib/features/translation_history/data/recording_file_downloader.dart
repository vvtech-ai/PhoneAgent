import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import '../domain/recording_audio.dart';
import 'recording_source_resolver.dart';

/// Private files only; URLs and authorization never become disk metadata.
class RecordingFileDownloader {
  RecordingFileDownloader({
    required this.root,
    required this.scope,
    required this.isCurrent,
    Dio? client,
    this.openDomestic,
  }) : _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.stream,
    );
  }
  final DomesticRecordingOpen? openDomestic;
  final Directory root;
  final String scope;
  final bool Function() isCurrent;
  final Dio _client;
  final _cancel = CancelToken();
  static final _locks = <String, Future<void>>{};
  bool _closed = false;

  void _check() {
    if (_closed || !isCurrent()) throw StateError('Recording unavailable');
  }

  Future<void> invalidate(RecordingDownloadSource source) async {
    _check();
    if (!await root.exists()) return;
    final canonical = await root.resolveSymbolicLinks();
    final path = '$canonical${Platform.pathSeparator}${_key(source)}.m4a';
    final previous = _locks[path] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[path] = done.future;
    try {
      await previous;
      _check();
      await _remove(File(path));
      await _remove(File('$path.part'));
    } finally {
      done.complete();
      if (identical(_locks[path], done.future)) _locks.remove(path);
    }
  }

  String _key(RecordingDownloadSource source) => crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode([
            scope,
            source.cacheKey,
            source.size,
            source.sha256.toLowerCase(),
          ]),
        ),
      )
      .toString();

  Future<RecordingAudioAsset> load(
    RecordingDownloadSource source, {
    required bool retry,
  }) async {
    _check();
    if (source.size < 0 ||
        source.cacheKey.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(source.sha256)) {
      throw const FormatException('Invalid recording integrity');
    }
    await root.create(recursive: true);
    final canonical = await root.resolveSymbolicLinks();
    final path = '$canonical${Platform.pathSeparator}${_key(source)}.m4a';
    final previous = _locks[path] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[path] = done.future;
    try {
      await previous;
      _check();
      final file = File(path), part = File('$path.part');
      await _regular(file);
      await _regular(part);
      if (retry) {
        await _remove(file);
        await _remove(part);
      }
      if (!await _valid(file, source)) {
        await _remove(file);
        if (await part.exists() && await part.length() > source.size) {
          await _remove(part);
        }
        if (!await _valid(part, source)) {
          // A complete but corrupt partial must never be resumed.
          if (await part.exists() && await part.length() == source.size) {
            await _remove(part);
          }
          await _download(part, source);
        }
        _check();
        if (!await _valid(part, source)) {
          await _remove(part);
          throw const FormatException('Recording checksum mismatch');
        }
        _check();
        await part.rename(file.path);
      }
      _check();
      return RecordingAudioAsset(
        file.path,
        source.fileName,
        source.contentType,
        size: source.size,
        sha256: source.sha256.toLowerCase(),
      );
    } finally {
      done.complete();
      if (identical(_locks[path], done.future)) _locks.remove(path);
    }
  }

  Future<void> _regular(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.notFound) {
      throw StateError('Invalid recording cache entry');
    }
  }

  Future<void> _remove(File file) async {
    await _regular(file);
    if (await file.exists()) await file.delete();
  }

  Future<bool> _valid(File file, RecordingDownloadSource source) async {
    if (!await file.exists() || await file.length() != source.size) {
      return false;
    }
    final hash = await crypto.sha256.bind(file.openRead()).first;
    _check();
    return hash.toString() == source.sha256.toLowerCase();
  }

  Future<void> _download(File part, RecordingDownloadSource source) async {
    var recovered416 = false;
    while (true) {
      _check();
      final offset = await part.exists() ? await part.length() : 0;
      final domestic = source.accountCallId;
      final open = openDomestic;
      if (domestic != null && open == null) {
        throw StateError('Authenticated recording transport unavailable');
      }
      final response = domestic != null
          ? await open!(domestic, offset, _cancel)
          : await _client.getUri<ResponseBody>(
              source.url,
              options: Options(
                headers: {
                  ...source.headers,
                  'Accept-Encoding': 'identity',
                  if (offset > 0) 'Range': 'bytes=$offset-',
                },
              ),
              cancelToken: _cancel,
            );
      final body = response.data;
      if (body == null) throw StateError('Recording response empty');
      final status = response.statusCode;
      if (status == 416 && offset > 0 && !recovered416) {
        await body.stream.listen(null).cancel();
        await _remove(part);
        recovered416 = true;
        continue;
      }
      var append = false;
      var expectedBody = source.size;
      try {
        _check();
        if (status != 200 && status != 206) {
          throw StateError('Recording download rejected');
        }
        if (status == 206) {
          final range = RegExp(
            r'^bytes (\d+)-(\d+)/(\d+)$',
          ).firstMatch(response.headers.value('content-range') ?? '');
          if (range == null ||
              int.parse(range[1]!) != offset ||
              int.parse(range[2]!) != source.size - 1 ||
              int.parse(range[3]!) != source.size) {
            await _remove(part);
            throw const FormatException('Invalid recording range');
          }
          append = offset > 0;
          expectedBody = source.size - offset;
        }
        final length = response.headers.value('content-length');
        if (length != null && int.tryParse(length) != expectedBody) {
          throw const FormatException('Invalid recording length');
        }
      } catch (_) {
        await body.stream.listen(null).cancel();
        rethrow;
      }
      final sink = await part.open(
        mode: append ? FileMode.append : FileMode.write,
      );
      var received = 0;
      var overflow = false;
      try {
        await for (final bytes in body.stream.timeout(
          const Duration(seconds: 90),
        )) {
          _check();
          received += bytes.length;
          if (received > expectedBody) {
            overflow = true;
            throw const FormatException('Recording length exceeded');
          }
          await sink.writeFrom(bytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
        if (overflow) await _remove(part);
      }
      _check();
      // A short response is retained solely for a later Range request.
      if (received != expectedBody) throw StateError('Recording interrupted');
      return;
    }
  }

  void close() {
    _closed = true;
    _cancel.cancel();
    _client.close(force: true);
  }
}
