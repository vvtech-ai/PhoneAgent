import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../../domain/recording/pcm_timeline.dart';

class RecordedPcmChunk {
  const RecordedPcmChunk(this.track, this.timestampNanos, this.pcm);
  final TranslationRecordingTrack track;
  final int timestampNanos;
  final Uint8List pcm;
}

/// Private, account-scoped journal. An overflow invalidates the entire capture.
class PcmRecordingJournal {
  PcmRecordingJournal._(this.file, this.originNanos, this._writer);
  final File file;
  final int originNanos;
  final RandomAccessFile? _writer;
  static const maxBytes = 300 * 1024 * 1024;
  static const maxChunkBytes = 1024 * 1024;
  static const _magic = 0x56565043;
  Future<void> _tail = Future.value();
  Future<void>? _finish;
  int _pending = 0, _bytes = 20;
  bool _invalid = false;
  bool get valid => !_invalid;

  static Future<PcmRecordingJournal> create({
    required Directory privateRoot,
    required String environment,
    required String apiBase,
    required String accountId,
    required String clientCallId,
    required int originNanos,
  }) async {
    if ([
      environment,
      apiBase,
      accountId,
      clientCallId,
    ].any((v) => v.trim().isEmpty)) {
      throw ArgumentError('Missing recording scope');
    }
    final scope = sha256.convert(
      utf8.encode(jsonEncode([environment, apiBase, accountId])),
    );
    final call = sha256.convert(utf8.encode(clientCallId));
    await privateRoot.create(recursive: true);
    var directory = Directory(await privateRoot.resolveSymbolicLinks());
    for (final component in ['translation-recordings', '$scope', '$call']) {
      directory = Directory(path.join(directory.path, component));
      if (!await directory.exists()) {
        await directory.create();
      }
      if (await directory.resolveSymbolicLinks() != directory.path) {
        throw const FormatException('Recording directory escaped owner');
      }
    }
    final file = File('${directory.path}/capture.pcmj');
    // Never overwrite a recoverable capture from the same call.
    if (await file.exists() || await File('${file.path}.complete').exists()) {
      throw StateError('Recording journal already exists');
    }
    final writer = await file.open(mode: FileMode.writeOnly);
    final header = ByteData(20)
      ..setUint32(0, _magic)
      ..setUint32(4, 1)
      ..setUint32(8, 16000)
      ..setInt64(12, originNanos);
    try {
      await writer.writeFrom(header.buffer.asUint8List());
      return PcmRecordingJournal._(file, originNanos, writer);
    } catch (_) {
      await writer.close();
      rethrow;
    }
  }

  static Future<PcmRecordingJournal> recover(File file) async {
    // Fully validate the stopped capture before handing it to finalization.
    await read(file).drain<void>();
    final reader = await file.open();
    try {
      final header = ByteData.sublistView(await reader.read(20));
      final value = PcmRecordingJournal._(file, header.getInt64(12), null);
      value._finish = Future<void>.value();
      return value;
    } finally {
      await reader.close();
    }
  }

  bool offer(RecordedPcmChunk chunk) {
    if (_finish != null || _invalid) {
      return false;
    }
    final size = chunk.pcm.length;
    if (size == 0 ||
        size.isOdd ||
        size > maxChunkBytes ||
        _pending >= 256 ||
        _bytes + 13 + size > maxBytes) {
      _invalid = true;
      return false;
    }
    final payload = Uint8List.fromList(chunk.pcm);
    final header = ByteData(13)
      ..setUint8(0, chunk.track.index)
      ..setInt64(1, chunk.timestampNanos)
      ..setUint32(9, size);
    _pending++;
    _bytes += 13 + size;
    _tail = _tail
        .then((_) async {
          if (!_invalid) {
            await _writer!.writeFrom(header.buffer.asUint8List());
            await _writer.writeFrom(payload);
          }
        })
        .catchError((Object _) {
          _invalid = true;
        })
        .whenComplete(() => _pending--);
    return true;
  }

  Future<void> finish() => _finish ??= _close();
  Future<void> _close() async {
    try {
      await _tail;
      await _writer!.flush();
    } catch (_) {
      _invalid = true;
    } finally {
      try {
        await _writer!.close();
      } catch (_) {
        _invalid = true;
      }
    }
    if (_invalid) {
      throw const FormatException('Recording capture invalid');
    }
    // A crash or invalid capture must never be recovered as complete audio.
    await File('${file.path}.complete').writeAsString('1', flush: true);
  }

  /// Yields one bounded chunk at a time, closing the file on errors/cancellation.
  static Stream<RecordedPcmChunk> read(File file) async* {
    if (!await File('${file.path}.complete').exists()) {
      throw const FormatException('Recording capture not finalized');
    }
    final reader = await file.open();
    try {
      final length = await reader.length();
      if (length < 20 || length > maxBytes) {
        throw const FormatException('Invalid recording journal size');
      }
      final raw = await reader.read(20);
      final header = ByteData.sublistView(raw);
      if (raw.length != 20 ||
          header.getUint32(0) != _magic ||
          header.getUint32(4) != 1 ||
          header.getUint32(8) != 16000) {
        throw const FormatException('Invalid recording journal header');
      }
      while (await reader.position() < length) {
        final rawChunk = await reader.read(13);
        if (rawChunk.length != 13) {
          throw const FormatException('Truncated recording journal');
        }
        final chunk = ByteData.sublistView(rawChunk);
        final track = chunk.getUint8(0), size = chunk.getUint32(9);
        if (track >= TranslationRecordingTrack.values.length ||
            size == 0 ||
            size.isOdd ||
            size > maxChunkBytes ||
            size > length - await reader.position()) {
          throw const FormatException('Invalid recording chunk');
        }
        final pcm = await reader.read(size);
        if (pcm.length != size) {
          throw const FormatException('Truncated recording PCM');
        }
        yield RecordedPcmChunk(
          TranslationRecordingTrack.values[track],
          chunk.getInt64(1),
          pcm,
        );
      }
    } finally {
      await reader.close();
    }
  }
}
