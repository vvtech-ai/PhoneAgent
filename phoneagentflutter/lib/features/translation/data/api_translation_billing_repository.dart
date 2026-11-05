import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/translation_billing.dart';

/// Account billing metadata only. Never changes local overseas selection or
/// treats server configured/available as geographic eligibility.
class ApiTranslationBillingRepository implements TranslationBillingRepository {
  const ApiTranslationBillingRepository(this.api);
  final AccountApi api;
  @override
  Future<Map<String, double>> load() async => decode(
    await api.request('api/account/settings/realtime-translation-provider'),
  );

  static Map<String, double> decode(Object? value) {
    final providers = AccountApi.object(value)['providers'];
    if (providers is! List) throw ApiFailure.invalidResponse;
    final result = <String, double>{};
    for (final item in providers) {
      final dto = AccountApi.object(item);
      final raw = dto['provider'];
      if (raw is! String) throw ApiFailure.invalidResponse;
      final id = overseasTranslationModel(raw);
      final rate = dto['billingMultiplier'];
      if (id != null && rate is num && rate.isFinite && rate > 0) {
        result[id] = rate.toDouble();
      }
    }
    return Map.unmodifiable(result);
  }
}
