import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';

class ApiPointsBilling {
  const ApiPointsBilling(this.api);
  final AccountApi api;
  Future<int?> load() async {
    final data = AccountApi.object(
      await api.request('api/points/global-config/published'),
    );
    final rate = data['billingBasePointsPerMinute'];
    if (rate == null) return null;
    if (rate is! int) throw ApiFailure.invalidResponse;
    return rate > 0 ? rate : null;
  }
}
