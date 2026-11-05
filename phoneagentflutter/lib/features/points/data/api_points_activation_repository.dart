import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/points_activation.dart';
import 'api_points_wallet_repository.dart';

class ApiPointsActivationRepository implements PointsActivationRepository {
  const ApiPointsActivationRepository(this.api);
  final AccountApi api;

  @override
  Future<PointsActivation> activate() async {
    final data = AccountApi.object(
      await api.request('api/points/session-activations', method: 'POST'),
    );
    final grants = data['grantEvents'] ?? const [];
    if (grants is! List) throw ApiFailure.invalidResponse;
    return PointsActivation(
      ApiPointsWalletRepository.parseAccount(
        AccountApi.object(data['walletSummary']),
      ),
      List.unmodifiable(
        grants.map((value) {
          final item = AccountApi.object(value);
          if (item['type'] is! String ||
              item['amount'] is! int ||
              item['businessDate'] is! String) {
            throw ApiFailure.invalidResponse;
          }
          return PointsGrant(
            item['type'],
            item['amount'],
            item['businessDate'],
          );
        }),
      ),
    );
  }
}
