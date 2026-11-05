import 'dart:convert';
import '../domain/points_wallet.dart';
import '../domain/points_wallet_cache.dart';

abstract final class PointsWalletCacheCodec {
  static const maxBytes = 1024 * 1024, maxRows = 5000;
  static String encode(String scope, PointsWalletSnapshot snapshot) {
    if (snapshot.items.length > maxRows ||
        snapshot.page < 0 ||
        snapshot.savedAtMillis < 0) {
      throw const FormatException('Invalid wallet snapshot');
    }
    final account = snapshot.account;
    final encoded = jsonEncode({
      'version': 1,
      'scope': scope,
      'savedAt': snapshot.savedAtMillis,
      'page': snapshot.page,
      'hasNext': snapshot.hasNext,
      'account': {
        'total': account.totalBalance,
        'available': account.availableBalance,
        'held': account.heldBalance,
        'updatedAt': account.updatedAt,
        'grantReceived': account.todayDailyGrantReceived,
        'grantPoints': account.todayDailyGrantPoints,
      },
      'items': [
        for (final row in snapshot.items)
          {
            'id': row.id,
            'type': row.type,
            'title': row.title,
            'delta': row.delta,
            'balanceAfter': row.balanceAfter,
            'description': row.description,
            'occurredAt': row.occurredAt,
          },
      ],
    });
    if (utf8.encode(encoded).length > maxBytes) {
      throw const FormatException('Wallet snapshot too large');
    }
    return encoded;
  }

  static PointsWalletSnapshot? decode(String scope, String? raw) {
    if (raw == null ||
        raw.length > maxBytes ||
        utf8.encode(raw).length > maxBytes) {
      return null;
    }
    try {
      final root = _map(jsonDecode(raw)), account = _map(root['account']);
      final rows = root['items'];
      if (root['version'] != 1 ||
          root['scope'] != scope ||
          rows is! List ||
          rows.length > maxRows ||
          root['hasNext'] is! bool ||
          account['grantReceived'] is! bool ||
          _int(root, 'page') < 0 ||
          _int(root, 'savedAt') < 0) {
        return null;
      }
      final seen = <int>{};
      final items = rows
          .map((value) {
            final row = _map(value), id = _int(_map(value), 'id');
            if (!seen.add(id)) {
              throw const FormatException('Duplicate wallet row');
            }
            return PointsLedgerItem(
              id: id,
              type: _text(row, 'type'),
              title: _text(row, 'title'),
              delta: _int(row, 'delta'),
              balanceAfter: _int(row, 'balanceAfter'),
              description: _text(row, 'description'),
              occurredAt: _text(row, 'occurredAt'),
            );
          })
          .where((item) => item.delta != 0)
          .toList();
      return PointsWalletSnapshot(
        account: PointsAccount(
          totalBalance: _int(account, 'total'),
          availableBalance: _int(account, 'available'),
          heldBalance: _int(account, 'held'),
          updatedAt: _text(account, 'updatedAt'),
          todayDailyGrantReceived: account['grantReceived'] as bool,
          todayDailyGrantPoints: _int(account, 'grantPoints'),
        ),
        items: items,
        page: _int(root, 'page'),
        hasNext: root['hasNext'] as bool,
        savedAtMillis: _int(root, 'savedAt'),
      );
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid wallet object');
    }
    return value;
  }

  static int _int(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! int) throw const FormatException('Invalid wallet number');
    return result;
  }

  static String _text(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! String) throw const FormatException('Invalid wallet text');
    return result;
  }
}
