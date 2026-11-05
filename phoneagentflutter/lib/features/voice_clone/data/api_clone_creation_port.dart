import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../../call_models/domain/call_models.dart';
import '../../call_models/domain/clone_voice.dart';
import '../domain/clone_creation.dart';

class ApiCloneCreationPort implements CloneCreationPort {
  const ApiCloneCreationPort(
    this.api, {
    required this.points,
    required this.recording,
  });
  final AccountApi api;
  final Future<int> Function() points;
  final Future<bool> Function() recording;
  @override
  Future<int> availablePoints() => CloneDiagnostics(
    api.diagnostics,
  ).run(DiagnosticCloneStage.admission, points);
  @override
  Future<bool> hasValidRecording() => CloneDiagnostics(api.diagnostics).run(
    DiagnosticCloneStage.recordingRead,
    recording,
    state: (v) => v ? 'present' : 'missing',
  );
  @override
  Future<List<CloneCreationModel>> models() async {
    try {
      return await CloneDiagnostics(
        api.diagnostics,
      ).run(DiagnosticCloneStage.modelDirectory, _loadModels);
    } on ApiFailure catch (error) {
      throw switch (error) {
        ApiFailure.network => CloneCatalogFailure.network,
        ApiFailure.signedOut => CloneCatalogFailure.signedOut,
        ApiFailure.sessionChanged => CloneCatalogFailure.sessionChanged,
        ApiFailure.unavailable => CloneCatalogFailure.configuration,
        ApiFailure.invalidResponse => CloneCatalogFailure.invalidResponse,
        ApiFailure.rejected => CloneCatalogFailure.serviceUnavailable,
      };
    }
  }

  Future<List<CloneCreationModel>> _loadModels() async {
    final root = AccountApi.object(
      await api.request('api/account/settings/voice-clone/models'),
    );
    final list = root['models'] ?? const [];
    if (list is! List) throw ApiFailure.invalidResponse;
    final result = <CloneCreationModel>[];
    final seen = <String>{};
    for (final raw in list) {
      final item = AccountApi.object(raw);
      final id = normalizeProvider(_text(item, 'modelId'));
      if (!supportsCloneVoice(id) || item['supportsVoiceClone'] == false) {
        continue;
      }
      if (!seen.add(id)) {
        throw ApiFailure.invalidResponse;
      }
      final current = item['current'] == null
          ? null
          : AccountApi.object(item['current']);
      _checkModel(current, id);
      final candidate = item['candidate'] == null
          ? null
          : AccountApi.object(item['candidate']);
      _checkModel(candidate, id);
      result.add(
        CloneCreationModel(
          id: id,
          pricePoints: _price(item['pricePoints']),
          name: modelName(id, _text(item, 'displayName')),
          available: _available(item['available']),
          unavailableReason: _text(item, 'unavailableReason'),
          cloneEntitled: _entitled(item['cloneEntitled']),
          entitlementReason: _text(item, 'entitlementReason'),
          currentReady:
              current != null &&
              _text(current, 'status').toUpperCase() == 'READY' &&
              _text(current, 'providerAssetId').isNotEmpty,
          candidateReady:
              candidate != null &&
              _text(candidate, 'status').toUpperCase() == 'READY' &&
              _text(candidate, 'billingStatus').toUpperCase() == 'CHARGED',
          hasCandidate: candidate != null,
          candidateFailed:
              candidate != null &&
              _text(candidate, 'status').toUpperCase() == 'FAILED',
          candidateFromRecording:
              candidate != null &&
              _text(candidate, 'source').toUpperCase() == 'LOCAL_RECORDING',
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static int? _price(Object? raw) {
    if (raw == null) return null;
    final value = raw is int
        ? raw
        : raw is String
        ? int.tryParse(raw.trim())
        : null;
    if (value == null) throw ApiFailure.invalidResponse;
    return value > 0 ? value : null;
  }

  static bool? _entitled(Object? value) {
    if (value == null || value is bool) return value as bool?;
    throw ApiFailure.invalidResponse;
  }

  // Catalog is a summary, not an operable candidate. Missing ownership fields
  // inherit the enclosing model scope; explicitly different models still fail.
  static void _checkModel(Map<String, dynamic>? asset, String expected) {
    if (asset == null) return;
    final model = _text(asset, 'modelId');
    if (model.isNotEmpty && normalizeProvider(model) != expected) {
      throw ApiFailure.invalidResponse;
    }
  }

  static bool _available(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    throw ApiFailure.invalidResponse;
  }

  static String _text(Map<String, dynamic> value, String key) {
    final field = value[key];
    if (field == null) return '';
    if (field is String || field is num || field is bool) {
      return field.toString().trim();
    }
    throw ApiFailure.invalidResponse;
  }
}
