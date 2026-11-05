import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/points_wallet.dart';

class ApiPointsWalletRepository implements PointsWalletRepository {
  ApiPointsWalletRepository(this._api);
  final AccountApi _api;
  @override
  Future<PointsAccount> account() async {
    final m = AccountApi.object(await _api.request('api/points/account'));
    return parseAccount(m);
  }

  static PointsAccount parseAccount(Map<String, Object?> m) {
    final keys = [
      'membershipAvailableBalance',
      'membershipHeldBalance',
      'permanentAvailableBalance',
      'permanentHeldBalance',
    ];
    final hasSources = keys.any((key) => m[key] != null);
    if (hasSources &&
        (keys.any((key) => m[key] is! int || (m[key] as int) < 0) ||
            _int(m, keys[0]) + _int(m, keys[2]) !=
                _int(m, 'availableBalance') ||
            _int(m, keys[1]) + _int(m, keys[3]) != _int(m, 'heldBalance'))) {
      throw ApiFailure.invalidResponse;
    }
    final received = m['todayDailyGrantReceived'];
    if (received != null && received is! bool) throw ApiFailure.invalidResponse;
    return PointsAccount(
      totalBalance: _int(m, 'totalBalance'),
      availableBalance: _int(m, 'availableBalance'),
      heldBalance: _int(m, 'heldBalance'),
      updatedAt: _text(m, 'updatedAt'),
      todayDailyGrantReceived: received == true,
      todayDailyGrantPoints: _int(m, 'todayDailyGrantPoints', fallback: 0),
      membershipAvailableBalance: hasSources ? _int(m, keys[0]) : null,
      membershipHeldBalance: hasSources ? _int(m, keys[1]) : null,
      permanentAvailableBalance: hasSources ? _int(m, keys[2]) : null,
      permanentHeldBalance: hasSources ? _int(m, keys[3]) : null,
    );
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async {
    if (page < 0 || size < 1 || size > 100) throw ArgumentError('Invalid page');
    final m = AccountApi.object(
      await _api.request(
        'api/points/ledger',
        query: {'page': page, 'size': size},
      ),
    );
    final items = m['items'];
    if (items is! List ||
        _int(m, 'page') != page ||
        _int(m, 'size') < 1 ||
        _int(m, 'totalPages') < 0 ||
        _int(m, 'totalElements') < 0) {
      throw ApiFailure.invalidResponse;
    }
    return PointsLedgerPage(
      page: page,
      size: _int(m, 'size'),
      totalElements: _int(m, 'totalElements'),
      totalPages: _int(m, 'totalPages'),
      items: List.unmodifiable(
        items.map((value) {
          final row = AccountApi.object(value);
          return PointsLedgerItem(
            id: _int(row, 'ledgerId'),
            type: _text(row, 'type'),
            title: _text(row, 'displayName'),
            delta: _int(row, 'deltaPoints'),
            balanceAfter: _int(row, 'balanceAfter'),
            description: _text(row, 'description'),
            occurredAt: _text(row, 'occurredAt'),
          );
        }),
      ),
    );
  }

  static int _int(Map<String, Object?> m, String key, {int? fallback}) {
    final value = m[key] ?? fallback;
    if (value is! int) throw ApiFailure.invalidResponse;
    return value;
  }

  static String _text(Map<String, Object?> m, String key) {
    final value = m[key];
    if (value is! String) throw ApiFailure.invalidResponse;
    return value;
  }
}
