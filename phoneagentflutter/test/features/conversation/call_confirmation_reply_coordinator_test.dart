import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply_coordinator.dart';

class _Repository implements CallConfirmationReplyRepository {
  final pending = <Completer<CallReply>>[];
  @override
  Future<CallReply> classify(CallReplyScope scope, String text) {
    final result = Completer<CallReply>();
    pending.add(result);
    return result.future;
  }
}

const scope = (
  accountId: 'owner',
  sessionId: 's',
  toolId: 't',
  specSignature: 'card-v1',
  generation: 1,
  cardText: '当前卡片',
);

void main() {
  test(
    'duplicates coalesce and superseded card/account/run decisions are ignored',
    () async {
      final repository = _Repository();
      CallReplyScope? current = scope;
      final coordinator = CallConfirmationReplyCoordinator(
        repository: repository,
        currentScope: () => current,
      );
      final applied = <CallReply>[];
      expect(
        coordinator.submit('问题', scope, (_, result) => applied.add(result)),
        isTrue,
      );
      expect(
        coordinator.submit('问题', scope, (_, result) => applied.add(result)),
        isFalse,
      );
      current = (
        accountId: 'other',
        sessionId: 's',
        toolId: 't',
        specSignature: 'card-v1',
        generation: 1,
        cardText: '当前卡片',
      );
      repository.pending.single.complete(
        const CallReply(CallReplyDecision.confirm),
      );
      await Future<void>.delayed(Duration.zero);
      expect(applied, isEmpty);
      current = scope;
      coordinator.submit('旧回复', scope, (_, result) => applied.add(result));
      coordinator.submit('新回复', scope, (_, result) => applied.add(result));
      repository.pending[1].complete(
        const CallReply(CallReplyDecision.confirm),
      );
      repository.pending[2].complete(const CallReply(CallReplyDecision.wait));
      await Future<void>.delayed(Duration.zero);
      expect(applied.single.decision, CallReplyDecision.wait);
    },
  );
  test(
    'classification failure is unclear; invalidation suppresses later acceptance',
    () async {
      final repository = _Repository();
      final coordinator = CallConfirmationReplyCoordinator(
        repository: repository,
        currentScope: () => scope,
      );
      final applied = <CallReply>[];
      coordinator.submit('问题', scope, (_, result) => applied.add(result));
      repository.pending.single.completeError(StateError('unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(applied.single.unavailable, isTrue);
      coordinator.submit('确认', scope, (_, result) => applied.add(result));
      coordinator.invalidate();
      repository.pending.last.complete(
        const CallReply(CallReplyDecision.confirm),
      );
      await Future<void>.delayed(Duration.zero);
      expect(applied, hasLength(1));
    },
  );
  testWidgets('12-second timeout keeps confirmation pending', (tester) async {
    final repository = _Repository();
    final coordinator = CallConfirmationReplyCoordinator(
      repository: repository,
      currentScope: () => scope,
    );
    CallReply? reply;
    coordinator.submit('问题', scope, (_, result) => reply = result);
    await tester.pump(const Duration(seconds: 12));
    expect(reply?.unavailable, isTrue);
    repository.pending.single.complete(
      const CallReply(CallReplyDecision.confirm),
    );
    await tester.pump();
    expect(reply?.unavailable, isTrue);
  });
}
