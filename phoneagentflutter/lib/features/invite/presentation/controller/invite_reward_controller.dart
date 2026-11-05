import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/auth_gateway.dart';
import '../../domain/invite_store.dart';

class InviteReward {
  const InviteReward(this.operation, this.amount);
  final String operation;
  final int amount;
}

class InviteRewardState {
  const InviteRewardState({this.reward, this.error = '', this.busy = false});
  final InviteReward? reward;
  final String error;
  final bool busy;
}

class InviteRewardController extends StateNotifier<InviteRewardState> {
  InviteRewardController(this.store, this.account)
    : super(const InviteRewardState());
  final InviteStore store;
  final String account;
  String get _slot => 'reward:$account';
  Map<String, dynamic> _data = {};
  bool get failed => state.error.isNotEmpty;
  Future<void> initialize(LoginOutcome? outcome) async {
    if (state.busy) return;
    state = InviteRewardState(reward: state.reward, busy: true);
    try {
      _data = await store.read(_slot);
      if (!mounted) return;
      final grants =
          outcome?.grantEvents
              .where((g) => g.type == 'REFERRAL_INVITEE_GRANT' && g.amount > 0)
              .toList() ??
          [];
      final operation = outcome?.referralOperationId ?? '';
      final ack = (_data['ack'] is List ? _data['ack'] as List : [])
          .whereType<String>()
          .toSet();
      if (outcome?.accountId == account &&
          operation.isNotEmpty &&
          grants.length == 1 &&
          outcome?.referralPoints == grants.single.amount &&
          !ack.contains(operation)) {
        final next = {
          'ack': ack.toList(),
          'operation': operation,
          'amount': grants.single.amount,
        };
        await store.write(_slot, next);
        if (!mounted) return;
        _data = next;
      }
      final id = _data['operation'];
      final amount = _data['amount'];
      state = InviteRewardState(
        reward:
            id is String &&
                id.isNotEmpty &&
                amount is int &&
                amount > 0 &&
                !ack.contains(id)
            ? InviteReward(id, amount)
            : null,
      );
    } catch (_) {
      if (mounted) state = const InviteRewardState(error: '奖励通知读取失败，请重试');
    }
  }

  Future<void> acknowledge() async {
    final reward = state.reward;
    if (reward == null || state.busy) return;
    state = InviteRewardState(reward: reward, busy: true);
    try {
      final ack =
          (_data['ack'] is List ? _data['ack'] as List : [])
              .whereType<String>()
              .toSet()
            ..add(reward.operation);
      final next = <String, dynamic>{'ack': ack.toList()};
      await store.write(_slot, next);
      if (!mounted) return;
      _data = next;
      state = const InviteRewardState();
    } catch (_) {
      if (mounted) {
        state = InviteRewardState(reward: reward, error: '确认保存失败，请重试');
      }
    }
  }
}
