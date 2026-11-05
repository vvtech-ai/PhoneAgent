import '../../domain/recording/domestic_recording_attachment.dart';
import '../../domain/recording/domestic_recording_encoder.dart';
import '../../domain/recording/translation_recording_tap.dart';
import 'domestic_recording_finalizer.dart';
import 'pcm_recording_journal.dart';
import 'private_domestic_recording_files.dart';

/// Lifetime is the physical call, not the route or history screen.
class DomesticRecordingSession {
  DomesticRecordingSession._(
    this.journal,
    this.encoder,
    this.isCurrent,
    int Function() nowNanos,
  ) {
    tap = TranslationRecordingTap(
      nowNanos: nowNanos,
      sink: (track, timestamp, pcm) =>
          isCurrent() && journal.offer(RecordedPcmChunk(track, timestamp, pcm)),
    );
  }
  final PcmRecordingJournal journal;
  final DomesticRecordingEncoder encoder;
  final bool Function() isCurrent;
  late final TranslationRecordingTap tap;
  Future<DomesticRecordingAttachment>? _finish;

  static Future<DomesticRecordingSession> start({
    required PrivateDomesticRecordingFiles files,
    required String clientCallId,
    required DomesticRecordingEncoder encoder,
    required int Function() nowNanos,
    int? originNanos,
  }) async {
    final journal = await files.create(clientCallId, originNanos ?? nowNanos());
    return DomesticRecordingSession._(
      journal,
      encoder,
      files.isCurrent,
      nowNanos,
    );
  }

  Future<DomesticRecordingAttachment> finish(int durationMillis) =>
      _finish ??= _finalize(durationMillis);
  Future<DomesticRecordingAttachment> _finalize(int durationMillis) async {
    await journal.finish();
    if (!isCurrent() || !tap.available) {
      throw StateError('Recording unavailable');
    }
    final result = await DomesticRecordingFinalizer(
      encoder,
    ).finalize(journal: journal, durationMillis: durationMillis);
    if (!isCurrent()) {
      throw StateError('Recording owner changed');
    }
    return DomesticRecordingAttachment(
      durationMillis: result.durationMillis,
      checksumSha256: result.checksumSha256,
    );
  }
}
