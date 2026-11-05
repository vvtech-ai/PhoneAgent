import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/features/invite/data/secure_invite_store.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_reward_controller.dart';
import 'invite_state_test.dart' show success;

class _FailingStore extends MemoryInviteStore {
  bool failRead = false, failWrite = false;
  @override
  Future<Map<String, dynamic>> read(String slot) async {
    if (failRead) throw StateError('synthetic read failure');
    return super.read(slot);
  }

  @override
  Future<void> write(String slot, Map<String, dynamic> value) async {
    if (failWrite) throw StateError('synthetic write failure');
    return super.write(slot, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'secure slots isolate environments and accounts; writes remain ordered',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final a = SecureInviteStore('dev|https://example.test');
      final b = SecureInviteStore('prod|https://example.test');
      await Future.wait([
        a.write('pending', {'code': 'ABCD'}),
        a.write('pending', {'code': 'EFGH'}),
      ]);
      expect((await a.read('pending'))['code'], 'EFGH');
      expect(await b.read('pending'), isEmpty);
      await a.write('reward:a', {'operation': 'op'});
      expect(await a.read('reward:b'), isEmpty);
    },
  );
  test(
    'read failure prevents a new registration id; recovery reuses durable id',
    () async {
      final store = _FailingStore();
      final first = PendingInviteController(store);
      final id = await first.begin('13800000000', 'ABCD');
      first.finish();
      first.dispose();
      store.failRead = true;
      final restored = PendingInviteController(store);
      await expectLater(
        restored.begin('13800000000', 'ABCD'),
        throwsA(isA<InviteFailure>()),
      );
      store.failRead = false;
      expect(await restored.begin('13800000000', 'ABCD'), id);
      restored.dispose();
    },
  );
  test('failed acknowledgement retains reward and remains retryable', () async {
    final store = _FailingStore();
    final reward = InviteRewardController(store, 'a');
    await reward.initialize(success());
    store.failWrite = true;
    await reward.acknowledge();
    expect(reward.state.reward?.amount, 20);
    expect(reward.failed, isTrue);
    store.failWrite = false;
    await reward.acknowledge();
    expect(reward.state.reward, isNull);
    reward.dispose();
  });
}
