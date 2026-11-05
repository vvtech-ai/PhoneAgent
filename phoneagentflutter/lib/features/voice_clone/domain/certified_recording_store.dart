import 'dart:typed_data';
import 'clone_candidate.dart';

enum RecordingStoreFailure { corrupt, unavailable, sessionChanged }

abstract interface class CertifiedRecordingBlobStore {
  Future<Uint8List?> read();
  Future<void> replace(Uint8List payload);
  Future<void> clear();
}

abstract interface class CertifiedRecordingDownload {
  Future<Uint8List> download(CloneRecordingGrant grant);
}

class CertifiedRecordingRead {
  const CertifiedRecordingRead.absent() : recording = null, invalid = false;
  const CertifiedRecordingRead.invalid() : recording = null, invalid = true;
  const CertifiedRecordingRead.ready(this.recording) : invalid = false;
  final CertifiedCloneRecording? recording;
  final bool invalid;
}
