import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/data/points_wallet_cache_codec.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  test(
    'snapshot roundtrip retains account, held amount, ledger cursor and hasNext',
    () {
      final raw = PointsWalletCacheCodec.encode('scope', pointsSnapshot());
      final restored = PointsWalletCacheCodec.decode('scope', raw)!;
      expect(restored.account.availableBalance, 120);
      expect(restored.account.heldBalance, 20);
      expect(restored.items.map((r) => r.id), [1, 2]);
      expect(restored.page, 1);
      expect(restored.hasNext, true);
      expect(() => restored.items.clear(), throwsUnsupportedError);
    },
  );
  test('wrong scope, schema and malformed JSON are cache misses', () {
    final raw = PointsWalletCacheCodec.encode('scope', pointsSnapshot());
    expect(PointsWalletCacheCodec.decode('other', raw), isNull);
    for (final invalid in [
      'null',
      '{}',
      '{',
      '[]',
      raw.replaceFirst('"version":1', '"version":2'),
    ]) {
      expect(PointsWalletCacheCodec.decode('scope', invalid), isNull);
    }
  });
  for (final field in ['page', 'savedAt', 'hasNext', 'account', 'items']) {
    test('malformed $field is a miss not a partly trusted wallet', () {
      final data =
          jsonDecode(PointsWalletCacheCodec.encode('scope', pointsSnapshot()))
              as Map<String, dynamic>;
      data[field] = 'bad';
      expect(PointsWalletCacheCodec.decode('scope', jsonEncode(data)), isNull);
    });
  }
  test(
    'duplicate stable IDs reject entire cache instead of duplicating rows',
    () {
      final data =
          jsonDecode(PointsWalletCacheCodec.encode('scope', pointsSnapshot()))
              as Map<String, dynamic>;
      final rows = data['items'] as List;
      rows.add(rows.first);
      expect(PointsWalletCacheCodec.decode('scope', jsonEncode(data)), isNull);
    },
  );
  test(
    'oversize input and row count are bounded without silently truncating',
    () {
      expect(
        PointsWalletCacheCodec.decode(
          'scope',
          'x' * (PointsWalletCacheCodec.maxBytes + 1),
        ),
        isNull,
      );
      final tooMany = PointsWalletSnapshot(
        account: pointsAccount(0),
        items: List.generate(5001, pointsRow),
        page: 0,
        hasNext: true,
        savedAtMillis: 0,
      );
      expect(
        () => PointsWalletCacheCodec.encode('scope', tooMany),
        throwsFormatException,
      );
    },
  );
  test('invalid account scalar is rejected without coercing to zero', () {
    final data =
        jsonDecode(PointsWalletCacheCodec.encode('scope', pointsSnapshot()))
            as Map<String, dynamic>;
    (data['account'] as Map)['available'] = '120';
    expect(PointsWalletCacheCodec.decode('scope', jsonEncode(data)), isNull);
  });
}
