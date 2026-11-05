import 'dart:convert';
import 'dart:typed_data';
import '../domain/certified_recording_store.dart';
import '../domain/clone_candidate.dart';
import 'certified_recording_codec.dart';

/// Access only through CertifiedRecordingRepository's shared slot queue.
/// Empty markers and recordings occupy the same atomic encrypted object.
class MigratingCertifiedRecordingStore implements CertifiedRecordingBlobStore {
  MigratingCertifiedRecordingStore({
    required this.target,
    required this.binding,
    required this.readLegacy,
    required this.isCurrent,
  }) : _empty = Uint8List.fromList(
         utf8.encode(
           jsonEncode({
             'legacyRecordingMigration': 1,
             'binding': binding,
             'empty': true,
           }),
         ),
       );
  final CertifiedRecordingBlobStore target;
  final String binding;
  final Future<CertifiedCloneRecording?> Function() readLegacy;
  final bool Function() isCurrent;
  final Uint8List _empty;

  void _check() {
    if (!isCurrent()) throw RecordingStoreFailure.sessionChanged;
  }

  bool _isEmpty(Uint8List bytes) {
    if (bytes.length != _empty.length) return false;
    for (var index = 0; index < bytes.length; index++) {
      if (bytes[index] != _empty[index]) return false;
    }
    return true;
  }

  @override
  Future<Uint8List?> read() async {
    _check();
    final saved = await target.read();
    _check();
    if (saved != null) return _isEmpty(saved) ? null : saved;
    final legacy = await readLegacy();
    _check();
    final payload = legacy == null
        ? _empty
        : CertifiedRecordingCodec.encode(binding, legacy);
    await target.replace(payload);
    _check();
    return legacy == null ? null : payload;
  }

  @override
  Future<void> replace(Uint8List payload) async {
    _check();
    CertifiedRecordingCodec.decode(binding, payload);
    await target.replace(payload);
    _check();
  }

  @override
  Future<void> clear() async {
    _check();
    // Do not delete then mark: a crash in that gap could resurrect the old file.
    await target.replace(_empty);
    _check();
  }
}
