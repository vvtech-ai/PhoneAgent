import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import '../../translation_history/domain/recording_audio.dart';
import '../domain/call_recording_save.dart';

/// One-shot private export staging; not a server-hash-verified playback cache.
class CallRecordingFileDownload implements CallRecordingDownload {
  CallRecordingFileDownload({
    required this.root,
    required this.apiBase,
    required this.scope,
    required this.isCurrent,
    Dio? client,
    this.maxBytes = 512 * 1024 * 1024,
  }) : _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.stream,
    );
  }
  final Future<String> Function() root;
  final Uri apiBase;
  final String scope;
  final bool Function() isCurrent;
  final int maxBytes;
  final Dio _client;
  final _owned = <String>{};
  CancelToken? _cancel;
  bool _closed = false;
  void _check() {
    if (_closed || !isCurrent()) throw StateError('Recording unavailable');
  }

  @override
  Future<RecordingAudioAsset> download(RecordingAudioAsset source) async {
    _check();
    if (_cancel != null) throw StateError('Recording download busy');
    final uri = source.remoteUri;
    final prefix =
        '${apiBase.toString().replaceFirst(RegExp(r'/+$'), '')}/api/agent-calls/recording-content/';
    if (uri == null ||
        !uri.toString().startsWith(prefix) ||
        !RegExp(
          r'^[a-f0-9]{32}$',
        ).hasMatch(uri.toString().substring(prefix.length)) ||
        !{'http', 'https'}.contains(apiBase.scheme) ||
        apiBase.userInfo.isNotEmpty ||
        maxBytes <= 0 ||
        (source.size != null &&
            (source.size! <= 0 || source.size! > maxBytes))) {
      throw const FormatException('Invalid recording source');
    }
    final cancellation = _cancel = CancelToken();
    File? file;
    RandomAccessFile? output;
    var completed = false;
    try {
      final directory = Directory(await root());
      _check();
      await directory.create(recursive: true);
      final canonical = await directory.resolveSymbolicLinks();
      final nonce = List.generate(
        8,
        (_) => Random.secure().nextInt(1 << 32),
      ).join(':');
      final key = crypto.sha256
          .convert(utf8.encode('$scope:$nonce'))
          .toString();
      file = File('$canonical${Platform.pathSeparator}$key.m4a');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Recording staging collision');
      }
      _owned.add(file.path);
      output = await file.open(mode: FileMode.writeOnly);
      _check();
      final response = await _client.get<ResponseBody>(
        uri.toString(),
        cancelToken: cancellation,
        onReceiveProgress: (received, total) {
          if (_closed ||
              !isCurrent() ||
              received > maxBytes ||
              total > maxBytes) {
            cancellation.cancel();
          }
        },
      );
      _check();
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        if (body != null) await body.stream.listen(null).cancel();
        throw const FormatException('Recording download rejected');
      }
      final lengthText = response.headers.value(Headers.contentLengthHeader);
      final length = lengthText == null ? null : int.tryParse(lengthText);
      final type = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim();
      if (type == null ||
          !type.startsWith('audio/') ||
          (lengthText != null &&
              (length == null || length <= 0 || length > maxBytes)) ||
          (source.size != null && length != null && source.size != length)) {
        await body.stream.listen(null).cancel();
        throw const FormatException('Invalid recording response');
      }
      var received = 0;
      await for (final bytes in body.stream) {
        _check();
        received += bytes.length;
        if (received > maxBytes ||
            (source.size != null && received > source.size!) ||
            (length != null && received > length)) {
          throw const FormatException('Recording too large');
        }
        await output.writeFrom(bytes);
      }
      if (received == 0 ||
          (source.size != null && received != source.size) ||
          (length != null && received != length)) {
        throw const FormatException('Incomplete recording');
      }
      await output.flush();
      await output.close();
      output = null;
      final digest = await crypto.sha256.bind(file.openRead()).first;
      _check();
      completed = true;
      return RecordingAudioAsset(
        file.path,
        source.fileName,
        source.contentType,
        size: received,
        sha256: digest.toString(),
      );
    } finally {
      cancellation.cancel();
      _cancel = null;
      try {
        await output?.close();
      } finally {
        if (!completed && file != null && _owned.contains(file.path)) {
          await _remove(file.path);
        }
      }
    }
  }

  Future<void> _remove(String path) async {
    if (!_owned.contains(path)) throw StateError('Unowned recording');
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      throw StateError('Invalid staging file');
    }
    _owned.remove(path);
  }

  @override
  Future<void> remove(RecordingAudioAsset asset) => _remove(asset.localPath);
  @override
  void close() {
    _closed = true;
    _cancel?.cancel();
    _client.close(force: true);
  }
}
