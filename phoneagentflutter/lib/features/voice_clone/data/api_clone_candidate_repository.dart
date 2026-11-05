import '../domain/clone_request_failure.dart';
import 'clone_error_mapping.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/network/account_api.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_session.dart';
import '../domain/clone_candidate.dart';
import 'clone_candidate_mapper.dart';

/// Uses the account-bound API. It never retries a generation on network failure.
class ApiCloneCandidateRepository implements CloneCandidateRepository {
  const ApiCloneCandidateRepository(this.api, {this.expectedPricePoints});
  final int? expectedPricePoints;
  final AccountApi api;
  static const _root = 'api/account/settings/voice-clone/models';
  static const _stages = {
    'MFVC_MATERIAL': CloneGenerationFailure.material,
    'AUDIO_QUALITY': CloneGenerationFailure.audioQuality,
    'ASR_PROVIDER': CloneGenerationFailure.asrProvider,
    'ASR_CONTENT': CloneGenerationFailure.asrContent,
    'CLONE_PROVIDER': CloneGenerationFailure.cloneProvider,
    'CLONE_SUBMISSION_UNKNOWN': CloneGenerationFailure.submissionUnknown,
  };

  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async {
    final model = CloneCandidateMapper.model(modelId);
    final price = _confirmedPrice();
    final attempt = CloneCandidateMapper.identifier(attemptId);
    CloneCandidateMapper.identifier(requestId);
    try {
      final result = AccountApi.object(
        await api.request(
          '$_root/$model/candidates/from-verification/$attempt',
          method: 'POST',
          clonePricePoints: price,
          exposedCodes: cloneBusinessCodes,
          exposedDataStages: _stages.keys.toSet(),
          exposedStatuses: const {500, 501, 502, 503, 504, 507},
          idempotencyKey: attempt,
        ),
      );
      final candidate = CloneCandidateMapper.candidate(
        result['candidate'],
        model,
        onInvalid: _decodeFailure,
      );
      CloneRecordingGrant? recording;
      try {
        recording = CloneCandidateMapper.recording(
          result['recording'],
          attempt,
        );
        if (!recording.expiresAt.isAfter(DateTime.now())) {
          throw ApiFailure.invalidResponse;
        }
        _diagnose(DiagnosticOperation.voiceCloneRecordingGrant);
      } catch (error) {
        // Saving is optional. Invalid authority never invalidates a valid candidate.
        recording = null;
        _diagnose(DiagnosticOperation.voiceCloneRecordingGrant, error);
      }
      _diagnose(DiagnosticOperation.voiceCloneGeneration);
      return CloneGeneratedCandidate(candidate, recording: recording);
    } on ApiCodeFailure catch (error) {
      final business = cloneBusinessFailure(error.code);
      if (business != null) throw business;
      _diagnose(DiagnosticOperation.voiceCloneGeneration, error);
      throw CloneGenerationException(_stages[error.code]!, error.statusCode);
    } catch (error) {
      _diagnose(DiagnosticOperation.voiceCloneGeneration, error);
      rethrow;
    }
  }

  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String modelId,
    CertifiedCloneRecording recording,
    String requestId,
  ) async {
    final model = CloneCandidateMapper.model(modelId);
    final price = _confirmedPrice();
    if (sha256.convert(recording.audio).toString() !=
        recording.audioSha256.toLowerCase()) {
      throw ApiFailure.invalidResponse;
    }
    try {
      Object? result;
      try {
        result = await api.request(
          '$_root/$model/candidates/from-recording',
          method: 'POST',
          idempotencyKey: CloneCandidateMapper.identifier(requestId),
          clonePricePoints: price,
          body: {
            'audioBase64': base64Encode(recording.audio),
            'audioSha256': recording.audioSha256.toLowerCase(),
            'personFingerprint': recording.personFingerprint,
            'scriptVersion': recording.scriptVersion,
            'receipt': recording.receipt,
            'displayName': '我的声音',
          },
          exposedCodes: {
            ...cloneBusinessCodes,
            '认证身份已失效，请重新认证',
            '认证录音 receipt 无效或已过期',
          },
          exposedDataStages: _stages.keys.toSet(),
          exposedStatuses: const {500, 501, 502, 503, 504, 507},
        );
      } on ApiCodeFailure catch (error) {
        final business = cloneBusinessFailure(error.code);
        if (business != null) throw business;
        if (_stages.containsKey(error.code)) {
          throw CloneGenerationException(
            _stages[error.code]!,
            error.statusCode,
          );
        }
        // Only these two allowlisted server messages reach this branch. Never
        // inspect arbitrary error text or expose receipt/identity material.
        throw CloneGenerationFailure.identityExpired;
      }
      final candidate = CloneCandidateMapper.candidate(
        result,
        model,
        onInvalid: _decodeFailure,
      );
      _diagnose(DiagnosticOperation.voiceCloneGeneration);
      return CloneGeneratedCandidate(candidate);
    } catch (error) {
      _diagnose(DiagnosticOperation.voiceCloneGeneration, error);
      rethrow;
    }
  }

  int _confirmedPrice() {
    final price = expectedPricePoints;
    if (price == null || price <= 0) throw CloneRequestFailure.priceChanged;
    return price;
  }

  @override
  Future<CloneCandidate> read(String modelId) async {
    final model = CloneCandidateMapper.model(modelId);
    try {
      final candidate = CloneCandidateMapper.candidate(
        await api.request('$_root/$model/candidate'),
        model,
        onInvalid: _decodeFailure,
      );
      _diagnose(DiagnosticOperation.voiceCloneCandidateRead);
      return candidate;
    } catch (error) {
      _diagnose(DiagnosticOperation.voiceCloneCandidateRead, error);
      rethrow;
    }
  }

  void _decodeFailure(DiagnosticCloneDetails details) => emitDiagnostic(
    api.diagnostics,
    DiagnosticEvent(
      operation: DiagnosticOperation.voiceCloneCandidateDecode,
      result: DiagnosticResult.failed,
      failureKind: DiagnosticFailureKind.format,
      clone: details,
    ),
  );

  void _diagnose(DiagnosticOperation operation, [Object? error]) {
    emitDiagnostic(
      api.diagnostics,
      DiagnosticEvent(
        operation: operation,
        statusCode: switch (error) {
          ApiHttpFailure() => error.statusCode,
          ApiCodeFailure() => error.statusCode,
          CloneGenerationException() => error.httpStatus,
          _ => 0,
        },
        voiceCloneStage: error is CloneGenerationException
            ? DiagnosticVoiceCloneStage.values.byName(error.failure.name)
            : error is CloneGenerationFailure
            ? DiagnosticVoiceCloneStage.values.byName(error.name)
            : error is ApiCodeFailure && _stages.containsKey(error.code)
            ? DiagnosticVoiceCloneStage.values.byName(_stages[error.code]!.name)
            : null,
        result: error == null
            ? DiagnosticResult.succeeded
            : DiagnosticResult.failed,
        failureKind: error == null
            ? null
            : error == ApiFailure.invalidResponse
            ? DiagnosticFailureKind.format
            : error == ApiFailure.network
            ? DiagnosticFailureKind.other
            : DiagnosticFailureKind.state,
      ),
    );
  }
}
