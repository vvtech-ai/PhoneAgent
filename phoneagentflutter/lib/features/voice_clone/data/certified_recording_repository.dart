import 'dart:convert';
import '../../../core/diagnostics/diagnostic_event.dart';
import 'package:crypto/crypto.dart';
import '../domain/certified_recording_store.dart';
import '../domain/clone_candidate.dart';
import 'certified_recording_codec.dart';

class CertifiedRecordingRepository {
  CertifiedRecordingRepository({
    required this.binding,
    required this.blobs,
    required this.downloads,
    required this.isCurrent,
    this.diagnostics,
  });
  final String binding;
  final DiagnosticSink? diagnostics;
  final CertifiedRecordingBlobStore blobs;
  final CertifiedRecordingDownload downloads;
  final bool Function() isCurrent;
  bool _closed = false;
  static final _queues = <String, Future<void>>{};
  // Shared across same-slot repository instances, just like the serial queue.
  static int _nextWrite = 0;
  static final _completedWrites = <String, int>{};
  static String slot(String binding) =>
      sha256.convert(utf8.encode(binding)).toString();

  Future<CertifiedRecordingRead> read({String? personFingerprint}) =>
      _serial(() async {
        try {
          final payload = await blobs.read();
          _check();
          if (payload == null) return const CertifiedRecordingRead.absent();
          return CertifiedRecordingRead.ready(
            CertifiedRecordingCodec.decode(
              binding,
              payload,
              personFingerprint: personFingerprint,
            ),
          );
        } on FormatException {
          return _discardInvalid();
        } on RecordingStoreFailure catch (failure) {
          if (failure != RecordingStoreFailure.corrupt) rethrow;
          return _discardInvalid();
        }
      });

  Future<CertifiedRecordingRead> _discardInvalid() async {
    _check();
    await blobs.clear();
    _check();
    return const CertifiedRecordingRead.invalid();
  }

  Future<void> save(CloneRecordingGrant grant) async =>
      prepareSave(grant).commit();

  PreparedCloneRecordingSave prepareSave(CloneRecordingGrant grant) {
    _check();
    final write = ++_nextWrite;
    var cancelled = false;
    final payload = () async {
      final audio = await downloads.download(grant);
      _check();
      final recording = CertifiedCloneRecording(
        audio: audio,
        audioSha256: grant.audioSha256,
        personFingerprint: grant.personFingerprint,
        scriptVersion: grant.scriptVersion,
        receipt: grant.receipt,
      );
      return CertifiedRecordingCodec.encode(binding, recording);
    }();
    // A cancelled or slow confirmation must not leave an unhandled download.
    payload.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return _PreparedRecording(
      () => _serial(() async {
        try {
          final bytes = await payload;
          _check();
          if (cancelled) return;
          await blobs.replace(bytes);
          _completedWrites[slot(binding)] = write;
          _check();
          emitDiagnostic(
            diagnostics,
            DiagnosticEvent(
              operation: DiagnosticOperation.voiceCloneRecordingSave,
              result: DiagnosticResult.succeeded,
            ),
          );
        } catch (_) {
          emitDiagnostic(
            diagnostics,
            DiagnosticEvent(
              operation: DiagnosticOperation.voiceCloneRecordingSave,
              result: DiagnosticResult.failed,
              failureKind: DiagnosticFailureKind.state,
            ),
          );
          rethrow;
        }
      }),
      () => cancelled = true,
    );
  }

  /// Retryable deletion boundary. Later successful replacements belong to a
  /// newer workflow and must survive even when they contain identical audio.
  Future<void> Function() prepareClear() {
    final through = _nextWrite;
    var done = false;
    return () => _serial(() async {
      if (done) return;
      if ((_completedWrites[slot(binding)] ?? 0) <= through) {
        await blobs.clear();
        _check();
      }
      done = true;
    });
  }

  Future<void> clear() => _serial(() async {
    await blobs.clear();
    _check();
  });

  Future<T> _serial<T>(Future<T> Function() operation) {
    final key = slot(binding);
    final previous = _queues[key] ?? Future<void>.value();
    final result = previous.then((_) {
      _check();
      return operation();
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queues[key] = tail;
    tail.then((_) {
      if (identical(_queues[key], tail)) _queues.remove(key);
    });
    return result;
  }

  void _check() {
    if (_closed || !isCurrent()) throw RecordingStoreFailure.sessionChanged;
  }

  void close() {
    _closed = true;
  }
}

class _PreparedRecording implements PreparedCloneRecordingSave {
  _PreparedRecording(this._commit, this._cancel);
  final Future<void> Function() _commit;
  final void Function() _cancel;
  Future<void>? _committed;
  @override
  Future<void> commit() => _committed ??= _commit();
  @override
  void cancel() => _cancel();
}
