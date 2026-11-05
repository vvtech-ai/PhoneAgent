import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/clone_enrollment.dart';
import '../domain/clone_sdk_diagnosis.dart';
import '../domain/clone_verification.dart';
import 'clone_candidate_mapper.dart';
import 'clone_error_mapping.dart';
import 'clone_verification_error_mapping.dart';

class ApiCloneVerificationRepository implements CloneVerificationRepository {
  const ApiCloneVerificationRepository(this.api, {required this.modelId});
  final String modelId;
  final AccountApi api;
  static const _root = 'api/account/settings/voice-clone/verification';
  static const consentVersion = 'voice-clone-enrollment-v2';

  @override
  Future<bool> replacementRequired(String identityNumber) async {
    final number = _identityNumber(identityNumber);
    final data = AccountApi.object(
      await api.request(
        '$_root/replacement-check',
        method: 'POST',
        body: {'certType': 'IDENTITY_CARD', 'certNo': number},
      ),
    );
    final required = data['replacementRequired'];
    if (required is! bool) _invalid(data, 'replacementRequired');
    return required;
  }

  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String metaInfo,
  ) async {
    final model = CloneCandidateMapper.model(modelId);
    final number = _identityNumber(identity.number);
    final name = identity.name.trim();
    if (name.length < 2 || name.length > 32 || metaInfo.trim().isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    final data = AccountApi.object(
      await cloneVerificationRequest(
        () => api.request(
          '$_root/init',
          exposedCodes: cloneBusinessCodes,
          exposedMessage: cloneVerificationErrorMessage,
          method: 'POST',
          body: {
            'modelId': model,
            'consentVersion': consentVersion,
            'realName': name,
            'certType': 'IDENTITY_CARD',
            'certNo': number,
            'metaInfo': metaInfo,
            'replacementConfirmed': identity.replacementConfirmed,
          },
        ),
      ),
    );
    if (_status(data) != VerificationStatus.initiated) {
      _invalid(data, 'status');
    }
    return VerificationAttempt(
      id: CloneCandidateMapper.identifier(_text(data, 'attemptId')),
      certifyId: _text(data, 'certifyId'),
      script: _text(data, 'scriptText').trim(),
      expiresAt: _expiry(data),
      scriptVersion: _optional(data, 'scriptVersion'),
      scriptTemplateId: _optional(data, 'scriptTemplateId'),
    );
  }

  @override
  Future<VerificationSnapshot> read(String attemptId) async {
    final attempt = CloneCandidateMapper.identifier(attemptId);
    final data = AccountApi.object(await api.request('$_root/$attempt'));
    if (_text(data, 'attemptId') != attempt) _invalid(data, 'attemptId');
    final subCode = _optional(data, 'providerSubCode');
    // Only these known UI diagnoses survive; arbitrary provider text is discarded.
    return VerificationSnapshot(
      attempt,
      _status(data),
      _expiry(data),
      providerSubCode: const {'205', '220'}.contains(subCode) ? subCode : null,
    );
  }

  @override
  Future<void> observe(
    String attemptId,
    VerificationObservation observation,
  ) async {
    final attempt = CloneCandidateMapper.identifier(attemptId);
    if (observation.deviceModel.trim().isEmpty ||
        observation.deviceModel.length > 64 ||
        !CloneSdkDiagnosis.networks.contains(observation.networkType) ||
        !CloneSdkDiagnosis.categories.contains(observation.reasonCategory) ||
        observation.sdkCode < -1 ||
        observation.sdkCode > 9999 ||
        observation.sdkElapsedMs < 0 ||
        observation.sdkElapsedMs > 3600000 ||
        (observation.sdkSubCode != null &&
            !RegExp(
              r'^[ZA]\d{4}(?:_\d+)?$',
            ).hasMatch(observation.sdkSubCode!))) {
      throw ApiFailure.invalidResponse;
    }
    final data = AccountApi.object(
      await api.request(
        '$_root/$attempt/client-observation',
        method: 'POST',
        body: {
          'deviceModel': observation.deviceModel,
          'networkType': observation.networkType,
          'networkValidated': observation.networkValidated,
          'sdkCode': observation.sdkCode,
          if (observation.sdkSubCode != null)
            'sdkSubCode': observation.sdkSubCode,
          'reasonCategory': observation.reasonCategory,
          'sdkElapsedMs': observation.sdkElapsedMs,
        },
      ),
    );
    if (data['accepted'] != true) throw ApiFailure.invalidResponse;
  }

  static String _identityNumber(String number) {
    if (!validCloneIdentityNumber(number)) throw ApiFailure.invalidResponse;
    return number.trim().toUpperCase();
  }

  VerificationStatus _status(Map<String, dynamic> data) =>
      switch (_text(data, 'status').toUpperCase()) {
        'INIT' || 'INITIATED' => VerificationStatus.initiated,
        'PROCESSING' => VerificationStatus.processing,
        'PASS' => VerificationStatus.pass,
        'FAIL' => VerificationStatus.fail,
        'CANCELLED' => VerificationStatus.cancelled,
        'EXPIRED' => VerificationStatus.expired,
        'NEED_RETRY' => VerificationStatus.needRetry,
        _ => _invalid(data, 'status'),
      };
  String _text(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      _invalid(data, key);
    }
    return value;
  }

  String? _optional(Map<String, dynamic> data, String key) =>
      data[key] == null ? null : _text(data, key);
  String _expiry(Map<String, dynamic> data) {
    final value = _text(data, 'expiresAt');
    if (DateTime.tryParse(value) == null) _invalid(data, 'expiresAt');
    return value;
  }

  Never _invalid(Map<String, dynamic> data, String key) {
    final value = data[key];
    emitDiagnostic(
      api.diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.voiceCloneVerificationDecode,
        sessionId: CloneDiagnostics.current?.sessionId ?? '',
        result: DiagnosticResult.failed,
        failureKind: DiagnosticFailureKind.format,
        clone: DiagnosticCloneDetails(
          DiagnosticCloneField.values.byName(key),
          !data.containsKey(key)
              ? DiagnosticJsonType.absent
              : switch (value) {
                  String() => DiagnosticJsonType.text,
                  num() => DiagnosticJsonType.number,
                  bool() => DiagnosticJsonType.boolean,
                  Map() => DiagnosticJsonType.object,
                  List() => DiagnosticJsonType.array,
                  _ => DiagnosticJsonType.other,
                },
        ),
      ),
    );
    throw ApiFailure.invalidResponse;
  }
}
