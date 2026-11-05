import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../domain/outbound_number.dart';

class ApiOutboundNumberRepository implements OutboundNumberRepository {
  const ApiOutboundNumberRepository(this.api, this.accountId);
  final AccountApi api;
  final String accountId;
  static const path = 'api/account/settings/outbound-number';

  @override
  Future<OutboundNumber> load() async => _decode(await api.request(path));
  @override
  Future<OutboundNumber> save(String number) async => _decode(
    await api.request(path, method: 'POST', body: {'outboundNumber': number}),
  );
  @override
  Future<OutboundNumber> delete() async =>
      _decode(await api.request(path, method: 'DELETE'));

  OutboundNumber _decode(Object? value) {
    final dto = AccountApi.object(value);
    if (accountId.isEmpty || dto['accountId'] != accountId) {
      throw ApiFailure.sessionChanged;
    }
    final number = dto['outboundNumber'], configured = dto['configured'];
    if (number is! String || configured is! bool) {
      throw ApiFailure.invalidResponse;
    }
    return OutboundNumber(number, configured: configured);
  }
}
