import '../../../core/network/account_api.dart';
import '../../../core/diagnostics/diagnostic_clone_details.dart';
import '../../../core/network/account_session.dart';
import '../../call_models/domain/call_models.dart';
import '../../call_models/domain/clone_voice.dart';
import '../domain/clone_candidate.dart';

abstract final class CloneCandidateMapper {
  static String model(String value) {
    if (!supportsCloneVoice(value)) throw ApiFailure.invalidResponse;
    return normalizeProvider(value);
  }

  static String identifier(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
      throw ApiFailure.invalidResponse;
    }
    return value;
  }

  static CloneCandidate candidate(
    Object? value,
    String expectedModel, {
    void Function(DiagnosticCloneDetails)? onInvalid,
  }) {
    Never invalid(DiagnosticCloneField field, Object? raw) {
      final type = switch (raw) {
        null => DiagnosticJsonType.absent,
        String() => DiagnosticJsonType.text,
        num() => DiagnosticJsonType.number,
        bool() => DiagnosticJsonType.boolean,
        Map() => DiagnosticJsonType.object,
        List() => DiagnosticJsonType.array,
        _ => DiagnosticJsonType.other,
      };
      onInvalid?.call(DiagnosticCloneDetails(field, type));
      throw ApiFailure.invalidResponse;
    }

    if (value is! Map<String, dynamic>) {
      invalid(DiagnosticCloneField.candidate, value);
    }
    final data = value;
    String text(DiagnosticCloneField field) {
      final raw = data[field.name];
      if (raw == null) return '';
      if (raw is String || raw is num || raw is bool) return raw.toString();
      return invalid(field, raw);
    }

    int? points(DiagnosticCloneField field) {
      final raw = data[field.name];
      if (raw == null) return null;
      if (raw is! String && raw is! num) return invalid(field, raw);
      final text = raw.toString().trim();
      final integer = int.tryParse(text);
      if (integer != null) return integer;
      final number = double.tryParse(text);
      if (number == null ||
          !number.isFinite ||
          number != number.truncateToDouble()) {
        return invalid(field, raw);
      }
      // Match the native signed Long conversion, including its boundary check.
      final converted = number.toInt();
      if (converted.toDouble() != number) return invalid(field, raw);
      return converted;
    }

    final requested = model(expectedModel);
    final returned = text(DiagnosticCloneField.modelId).trim();
    if (returned.isNotEmpty && normalizeProvider(returned) != requested) {
      invalid(DiagnosticCloneField.modelId, data['modelId']);
    }
    final status = switch (text(DiagnosticCloneField.status).toUpperCase()) {
      'GENERATING' => CloneCandidateStatus.generating,
      'PROCESSING' => CloneCandidateStatus.processing,
      'READY' => CloneCandidateStatus.ready,
      'FAILED' => CloneCandidateStatus.failed,
      'CONFIRMED' => CloneCandidateStatus.confirmed,
      _ => CloneCandidateStatus.unknown,
    };
    final source = switch (text(DiagnosticCloneField.source).toUpperCase()) {
      'VERIFICATION' => CloneCandidateSource.verification,
      'LOCAL_RECORDING' => CloneCandidateSource.localRecording,
      _ => CloneCandidateSource.unknown,
    };
    final billing = switch (text(
      DiagnosticCloneField.billingStatus,
    ).toUpperCase()) {
      'NOT_RESERVED' => CloneBillingStatus.notReserved,
      'RESERVED' => CloneBillingStatus.reserved,
      'CHARGED' => CloneBillingStatus.charged,
      'RELEASED' => CloneBillingStatus.released,
      _ => CloneBillingStatus.unknown,
    };
    text(DiagnosticCloneField.updatedAt);
    return CloneCandidate(
      // Opaque server identity, never interpolated into a URL or HTTP header.
      id: text(DiagnosticCloneField.candidateId),
      modelId: requested,
      status: status,
      source: source,
      billing: billing,
      displayName: text(DiagnosticCloneField.displayName),
      lastError: text(DiagnosticCloneField.lastError),
      chargedPoints: points(DiagnosticCloneField.chargedPoints) ?? 0,
      remainingPoints: points(DiagnosticCloneField.remainingPoints),
      providerAssetId: text(DiagnosticCloneField.providerAssetId),
    );
  }

  static CloneRecordingGrant recording(Object? value, String attempt) {
    final data = AccountApi.object(value);
    if (_text(data, 'attemptId') != attempt) throw ApiFailure.invalidResponse;
    final digest = _text(data, 'audioSha256');
    final expiry = DateTime.tryParse(_text(data, 'expiresAt'));
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) || expiry == null) {
      throw ApiFailure.invalidResponse;
    }
    return CloneRecordingGrant(
      attemptId: attempt,
      grant: _text(data, 'grant'),
      receipt: _text(data, 'receipt'),
      audioSha256: digest.toLowerCase(),
      personFingerprint: _text(data, 'personFingerprint'),
      scriptVersion: _text(data, 'scriptVersion'),
      expiresAt: expiry,
    );
  }

  static String _text(
    Map<String, dynamic> data,
    String key, {
    bool optional = false,
  }) {
    final value = data[key];
    if (value == null && optional) return '';
    if (value is! String || (!optional && value.trim().isEmpty)) {
      throw ApiFailure.invalidResponse;
    }
    return value;
  }
}
