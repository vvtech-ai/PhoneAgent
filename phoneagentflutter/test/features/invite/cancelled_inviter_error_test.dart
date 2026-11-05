import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/data/api_invite_repository.dart';

void main() {
  test(
    'definite cancelled-inviter failure retires aborted request id',
    () async {
      final controller = PendingInviteController(MemoryInviteStore());
      addTearDown(controller.dispose);
      final first = await controller.begin('13800000000', 'BAD1');
      await controller.failed('INVITER_ACCOUNT_CANCELLED');
      final retry = await controller.begin('13800000000', 'BAD1');
      expect(retry, isNot(first));
    },
  );
  test(
    'cancelled inviter has exact Toast text and recognized business code',
    () {
      expect(inviteErrorCodes, contains('INVITER_ACCOUNT_CANCELLED'));
      expect(const InviteFailure('INVITER_ACCOUNT_CANCELLED').message, '邀请码无效');
    },
  );
}
