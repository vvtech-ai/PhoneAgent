import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_models.dart';
import '../domain/call_model_quality.dart';

class ApiCallModelQualityRepository implements CallModelQualityRepository {
  ApiCallModelQualityRepository(this._api);
  final AccountApi _api;
  @override
  Future<Map<String, CallModelReading>> refresh() async => readings(
    await _api.request(
      'api/assistant/realtime/call-models/latency',
      query: {'refresh': true},
    ),
  );

  static Map<String, CallModelReading> readings(Object? value) {
    final items = AccountApi.object(value)['models'];
    if (items is! List) throw ApiFailure.invalidResponse;
    final result = <String, CallModelReading>{};
    for (final item in items) {
      final dto = AccountApi.object(item);
      final provider = dto['provider'];
      final modelId = dto['modelId'];
      final available = dto['available'];
      final raw = dto['latencyMs'];
      final latency = raw is int
          ? raw
          : raw is String
          ? int.tryParse(raw)
          : null;
      if (provider is! String ||
          provider.trim().isEmpty ||
          (modelId != null && (modelId is! String || modelId.trim().isEmpty)) ||
          available is! bool ||
          (raw != null && latency == null)) {
        throw ApiFailure.invalidResponse;
      }
      final id = normalizeProvider(modelId is String ? modelId : provider);
      if (result.containsKey(id)) throw ApiFailure.invalidResponse;
      result[id] = CallModelReading.probe(
        available: available,
        latencyMs: latency,
      );
    }
    return Map.unmodifiable(result);
  }
}
