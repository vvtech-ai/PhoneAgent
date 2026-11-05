import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import 'dart:typed_data';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/certified_recording_store.dart';
import '../domain/clone_candidate.dart';
import 'clone_candidate_mapper.dart';
import 'certified_recording_codec.dart';

class ApiCertifiedRecordingDownload implements CertifiedRecordingDownload {
  ApiCertifiedRecordingDownload(this.api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AccountApi api;
  final DateTime Function() _now;
  @override
  Future<Uint8List> download(CloneRecordingGrant grant) {
    final attempt = CloneCandidateMapper.identifier(grant.attemptId);
    if (grant.grant.isEmpty || !_now().isBefore(grant.expiresAt)) {
      throw ApiFailure.invalidResponse;
    }
    return (CloneDiagnostics.current ?? CloneDiagnostics(api.diagnostics)).run(
      DiagnosticCloneStage.recordingDownload,
      () => api.download(
        'api/account/settings/voice-clone/verification/$attempt/certified-recording',
        maxBytes: CertifiedRecordingCodec.maxAudioBytes,
        mediaTypes: const {'audio/wav'},
        query: {'grant': grant.grant},
      ),
    );
  }
}
