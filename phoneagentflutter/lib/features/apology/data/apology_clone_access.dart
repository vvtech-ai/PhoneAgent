import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';

/// Fresh authorization for one catalog read, separate from asset readiness.
class ApologyCloneAccess {
  ApologyCloneAccess(this.api);
  final AccountApi api;
  Future<bool>? _unpublished;

  Future<bool> allows(Map<String, dynamic> model) async {
    if (model['entitlementReason'] == 'ENTITLEMENT_UNAVAILABLE') {
      throw ApiFailure.invalidResponse;
    }
    final entitled = model['cloneEntitled'];
    if (entitled is bool) return entitled;
    if (entitled != null || model['entitlementReason'] != null) {
      throw ApiFailure.invalidResponse;
    }
    // The server's legacy mode exists only before commerce is published.
    // Missing fields or a failed read cannot stand in for that evidence.
    if (await (_unpublished ??= _readUnpublished())) return true;
    throw ApiFailure.invalidResponse;
  }

  Future<bool> _readUnpublished() async {
    final catalog = AccountApi.object(
      await api.request('api/commerce/catalog'),
    );
    final version = catalog['configVersionId'];
    return version is int && version == 0;
  }
}
