import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/sip/domestic_provider_catalog.dart';

class ApiDomesticProviderRepository implements DomesticProviderRepository {
  const ApiDomesticProviderRepository(this.api, {this.region = 'DOMESTIC'});
  final String region;
  final AccountApi api;
  static const path = 'api/account/settings/realtime-translation-provider';
  @override
  Future<DomesticProviderCatalog> load() async =>
      decode(await api.request(path, query: {'region': region}));
  @override
  Future<DomesticProviderCatalog> select(String wireId) async {
    if (wireId.trim().isEmpty) throw ApiFailure.invalidResponse;
    final result = decode(
      await api.request(
        path,
        method: 'PUT',
        body: {'region': region, 'provider': wireId},
      ),
    );
    if (result.activeWireId != wireId) throw ApiFailure.invalidResponse;
    return result;
  }

  static DomesticProviderCatalog decode(Object? value) {
    final root = AccountApi.object(value),
        active = root['activeProvider'],
        raw = root['providers'];
    if (active is! String ||
        active.trim().isEmpty ||
        raw is! List ||
        raw.length > 64) {
      throw ApiFailure.invalidResponse;
    }
    final result = <DomesticProviderOption>[], seen = <String>{};
    for (final item in raw) {
      final dto = AccountApi.object(item), id = dto['provider'];
      if (id is! String || id.isEmpty || id.length > 100) {
        throw ApiFailure.invalidResponse;
      }
      final engine = domesticTranslationModel(id);
      final rate = dto['billingMultiplier'];
      if (!seen.add(id) ||
          dto['active'] is! bool ||
          dto['configured'] is! bool ||
          dto['available'] is! bool ||
          dto['statusMessage'] is! String ||
          (rate != null && (rate is! num || !rate.isFinite || rate <= 0))) {
        throw ApiFailure.invalidResponse;
      }
      result.add(
        DomesticProviderOption(
          wireId: id,
          engine: engine ?? '',
          name: dto['displayName'] is String
              ? dto['displayName'] as String
              : id == active && root['activeProviderDisplayName'] is String
              ? root['activeProviderDisplayName'] as String
              : id,
          subtitle: (dto['appSubtitle'] ?? dto['description']) is String
              ? (dto['appSubtitle'] ?? dto['description']) as String
              : '',
          active: dto['active'] as bool,
          configured: dto['configured'] as bool,
          available: dto['available'] as bool,
          statusMessage: dto['statusMessage'] as String,
          billingMultiplier: rate is num ? rate.toDouble() : null,
        ),
      );
    }
    if (!result.any((v) => v.wireId == active)) {
      throw ApiFailure.invalidResponse;
    }
    return DomesticProviderCatalog(activeWireId: active, options: result);
  }
}
