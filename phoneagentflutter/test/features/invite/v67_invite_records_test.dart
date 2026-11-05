import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/data/api_invite_repository.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'v67 masked number and actual ledger facts survive record contract',
    () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'items': [
            {
              'id': 'r1',
              'inviteePhone': '138****3508',
              'registeredAt': '2026-08-29T02:18:00Z',
              'inviterPoints': 300,
              'fullBonusPoints': 0,
              'inviterLedgerId': null,
              'fullBonusLedgerId': null,
            },
          ],
          'total': 1,
          'nextCursor': null,
        };
      final repo = ApiInviteRepository(
        backend.api,
        const InviteLinkPolicy(
          host: 'example.test',
          path: '/invite/',
          scheme: 'phoneagent-test',
        ),
      );
      final records = await repo.records();
      expect(records.items.single.maskedPhone, '138****3508');
      expect(records.items.single.credited, false);
      ((backend.data as Map)['items'] as List).first['inviterLedgerId'] =
          'ledger1';
      expect((await repo.records()).items.single.credited, true);
      backend.api.close();
    },
  );
}
