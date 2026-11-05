import 'dart:io';
import '../../domain/recording/domestic_recording_attachment.dart';
import '../../domain/recording/domestic_recording_encoder.dart';
import '../../domain/translation_archive.dart';
import 'domestic_recording_finalizer.dart';
import 'private_domestic_recording_files.dart';

/// Startup recovery only: never resumes microphone, model or SIP sessions.
class DomesticRecordingRecovery {
  const DomesticRecordingRecovery(this.files, this.encoder);
  final PrivateDomesticRecordingFiles files;
  final DomesticRecordingEncoder encoder;
  Future<TranslationArchiveEntry> prepare(TranslationArchiveEntry entry) async {
    if (!entry.recordingPending) return entry;
    if (entry.route != TranslationArchiveRoute.domesticSip ||
        entry.accountId != files.accountId ||
        entry.connectedAt == null ||
        entry.endedAt == null) {
      throw const FormatException('Invalid recording recovery owner');
    }
    try {
      final journal = await files.recover(entry.clientCallId);
      final result = await DomesticRecordingFinalizer(encoder).finalize(
        journal: journal,
        durationMillis: entry.endedAt! - entry.connectedAt!,
      );
      if (!files.isCurrent()) throw StateError('Recording owner changed');
      return entry.copy(
        recordingPending: false,
        recording: DomesticRecordingAttachment(
          durationMillis: result.durationMillis,
          checksumSha256: result.checksumSha256,
        ),
      );
    } on FormatException {
      // A stopped incomplete/corrupt capture is unavailable; do not fake audio.
      if (!files.isCurrent()) rethrow;
      return entry.copy(recordingPending: false);
    } on FileSystemException catch (error) {
      // Missing private capture cannot be recovered. Other disk errors retry.
      if (error.osError?.errorCode != 2 || !files.isCurrent()) rethrow;
      return entry.copy(recordingPending: false);
    }
  }
}
