import '../../translation/data/recording/domestic_recording_finalizer.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as paths;
import '../../translation/data/recording/private_domestic_recording_files.dart';
import '../../translation/data/recording/recording_encoding_receipt.dart';
import '../../translation/domain/recording/domestic_recording_attachment.dart';
import '../../translation/domain/recording/domestic_recording_encoder.dart';
import '../domain/local_translation_recording.dart';
import '../domain/translation_history.dart';
import '../domain/recording_audio.dart';

/// Exact archive identity only. Never searches by contact, phone or timestamp.
class PrivateLocalTranslationRecording implements LocalTranslationRecording {
  const PrivateLocalTranslationRecording(this.files, this.encoder);
  final PrivateDomesticRecordingFiles files;
  final DomesticRecordingEncoder encoder;
  static const manifest = 'recording.server-call.json';
  void _guard() {
    if (!files.isCurrent()) throw StateError('Recording owner changed');
  }

  String _id(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(value)) {
      throw const FormatException('Invalid recording identity');
    }
    return value;
  }

  Future<void> bind(String serverCallId, String clientCallId) async {
    _guard();
    _id(serverCallId);
    _id(clientCallId);
    final journal = await files.recover(clientCallId);
    _guard();
    final destination = File(paths.join(journal.file.parent.path, manifest));
    if (await FileSystemEntity.type(destination.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid recording link');
    }
    if (await destination.exists()) {
      final old = await _read(destination);
      if (old['server'] != serverCallId || old['client'] != clientCallId) {
        throw const FormatException('Conflicting recording identity');
      }
      return;
    }
    await destination.writeAsString(
      jsonEncode({'server': serverCallId, 'client': clientCallId}),
      flush: true,
    );
    _guard();
  }

  Future<Map<String, dynamic>> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > 1024) {
      throw const FormatException('Invalid recording link');
    }
    final value = jsonDecode(await file.readAsString());
    _guard();
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid recording link');
    }
    return value;
  }

  Future<String?> _client(String serverCallId) async {
    _guard();
    _id(serverCallId);
    final root = await files.root();
    _guard();
    final canonical = await root.resolveSymbolicLinks();
    final scope = sha256
        .convert(
          utf8.encode(
            jsonEncode([files.environment, files.apiBase, files.accountId]),
          ),
        )
        .toString();
    final directory = Directory(
      paths.join(canonical, 'translation-recordings', scope),
    );
    if (!await directory.exists()) return null;
    if (await directory.resolveSymbolicLinks() != directory.path) {
      throw const FormatException('Invalid recording directory');
    }
    var count = 0;
    await for (final item in directory.list(followLinks: false)) {
      _guard();
      if (++count > 4096) {
        throw const FormatException('Too many recording directories');
      }
      if (item is! Directory ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(paths.basename(item.path))) {
        continue;
      }
      final file = File(paths.join(item.path, manifest));
      if (!await file.exists()) continue;
      final value = await _read(file);
      if (value['server'] != serverCallId) continue;
      if (value['client'] is! String) {
        throw const FormatException('Invalid recording link');
      }
      final client = _id(value['client'] as String);
      if (sha256.convert(utf8.encode(client)).toString() !=
          paths.basename(item.path)) {
        throw const FormatException('Recording identity mismatch');
      }
      return client;
    }
    return null;
  }

  Future<({File file, DomesticRecordingAttachment receipt})?> _encoded(
    String serverCallId,
  ) async {
    final client = await _client(serverCallId);
    if (client == null) return null;
    File file;
    try {
      file = await files.recording(client);
    } on FileSystemException catch (error) {
      _guard();
      if (error.osError?.errorCode == 2) return null;
      rethrow;
    }
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    final size = await file.length();
    if (size <= 0 || size > 300 * 1024 * 1024) {
      throw const FormatException('Invalid local recording size');
    }
    final receipt = await RecordingEncodingReceipt.read(file);
    _guard();
    return receipt == null ? null : (file: file, receipt: receipt);
  }

  @override
  Future<bool> available(String serverCallId) async {
    try {
      final client = await _client(serverCallId);
      if (client == null) return false;
      try {
        // Resource existence controls visibility, not encoding readiness.
        // A damaged file must still expose the existing failure/retry card.
        await files.recording(client);
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 2) rethrow;
        await files.recover(client);
      }
      _guard();
      return true;
    } on FileSystemException {
      _guard();
      return false;
    } on FormatException {
      _guard();
      return false;
    }
  }

  @override
  Future<RecordingAudioAsset> load(TranslationHistory history) async {
    var encoded = await _encoded(history.callId);
    if (encoded == null) {
      final client = await _client(history.callId);
      if (client == null) throw StateError('Local recording unavailable');
      final journal = await files.recover(client);
      _guard();
      final finalizer = DomesticRecordingFinalizer(encoder);
      // Join atomically inside finalize, including completion between file
      // lookup and this call. A rounded SDK duration cannot invalidate receipt.
      await finalizer.finalize(
        journal: journal,
        durationMillis: history.durationMillis,
        reuseEncodedDuration: true,
      );
      _guard();
      encoded = await _encoded(history.callId);
    }
    if (encoded == null) throw StateError('Local recording unavailable');
    // A completed file owns its duration; SDK detail timestamps may be rounded.
    // Only a missing encoded file needs PCM recovery; completed files are reused.
    final source = encoded.file, checksum = encoded.receipt.checksumSha256;
    _guard();
    // Archive cleanup can remove the original after upload. Playback/export
    // owns a separate verified copy rather than racing that cleanup.
    final root = await files.root();
    final canonical = await root.resolveSymbolicLinks();
    final scope = sha256
        .convert(
          utf8.encode(
            jsonEncode([files.environment, files.apiBase, files.accountId]),
          ),
        )
        .toString();
    var directory = canonical;
    for (final segment in [
      'translation-playback',
      scope,
      sha256.convert(utf8.encode(history.callId)).toString(),
    ]) {
      _guard();
      directory = paths.join(directory, segment);
      final type = await FileSystemEntity.type(directory, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        await Directory(directory).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const FormatException('Invalid local playback directory');
      }
      if (await Directory(directory).resolveSymbolicLinks() != directory) {
        throw const FormatException('Invalid local playback directory');
      }
    }
    final destination = paths.join(directory, 'recording.m4a');
    if (await FileSystemEntity.type(destination, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid local playback file');
    }
    _guard();
    final copy = await source.copy(destination);
    _guard();
    if ((await sha256.bind(copy.openRead()).first).toString() != checksum) {
      throw const FormatException('Local playback copy checksum mismatch');
    }
    _guard();
    return RecordingAudioAsset(
      copy.path,
      'realtime-translation.m4a',
      'audio/mp4',
      size: await copy.length(),
      sha256: checksum,
    );
  }
}
