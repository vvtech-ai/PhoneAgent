import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/agent_failure.dart';
import 'package:phone_agent/features/conversation/domain/voice/conversation_turn_recovery.dart';
import 'turn_recovery_support.dart';

void main() {
  test('only ordinary network-failed user commands become recoverable', () {
    final recovery = ConversationTurnRecovery();
    for (final command in [
      recoveryCommand(kind: 'document'),
      recoveryCommand(action: 'confirm'),
    ]) {
      recovery.started(command);
      recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
      expect(recovery.pending, false);
    }
    for (final failure in [
      AgentTransportFailure.malformed,
      const AgentFailure(
        errorCode: 'MODEL_TIMEOUT',
        category: 'MODEL',
        message: 'network error',
      ),
    ]) {
      recovery.started(recoveryCommand());
      recovery.failed(failure, ordinaryTurn: true);
      expect(recovery.pending, false);
    }
    recovery.started(recoveryCommand());
    recovery.failed(AgentTransportFailure.network, ordinaryTurn: false);
    expect(recovery.pending, false);
    recovery.started(recoveryCommand());
    recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
    expect(recovery.baseText, '明天下午');
  });
  test(
    'committed assistant wins except after recovery-revision cancellation',
    () {
      final accepted = recoveryFact(1, 'USER_TURN_ACCEPTED', 'original');
      final cancelled = recoveryFact(2, 'RUN_CANCELLED', 'original');
      final reply = recoveryFact(3, 'ASSISTANT_TURN_COMMITTED', 'original');
      expect(
        ConversationTurnRecovery.resolve([
          reply,
          cancelled,
          accepted,
        ], 'original'),
        RecoveredTurnState.committed,
      );
      expect(
        ConversationTurnRecovery.resolve([
          accepted,
          recoveryFact(
            2,
            'RUN_CANCELLED',
            'original',
            stage: 'recovery_revision',
          ),
          reply,
        ], 'original'),
        RecoveredTurnState.terminated,
      );
      expect(
        ConversationTurnRecovery.resolve([reply], 'different'),
        RecoveredTurnState.notAccepted,
      );
      expect(
        ConversationTurnRecovery.resolve([accepted], 'original'),
        RecoveredTurnState.accepted,
      );
    },
  );
  test(
    'accepted or unknown original merges overlap with explicit supersedes',
    () async {
      for (final events in [
        <dynamic>[],
        [recoveryFact(1, 'USER_TURN_ACCEPTED', 'original')],
      ]) {
        final recovery = ConversationTurnRecovery()..started(recoveryCommand());
        recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
        final history = RecoveryFixture()
          ..result = recoveredHistory(events.cast());
        final plan = await recovery.plan('下午开会', history);
        expect(plan.text, '明天下午开会');
        expect(plan.supersedes, 'original');
        expect(plan.shouldSubmit, true);
      }
    },
  );
  test(
    'committed repeated input only syncs; new followup does not merge old sentence',
    () async {
      final recovery = ConversationTurnRecovery()..started(recoveryCommand());
      recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
      final history = RecoveryFixture()
        ..result = recoveredHistory([
          recoveryFact(1, 'ASSISTANT_TURN_COMMITTED', 'original', text: '已完成'),
        ]);
      expect((await recovery.plan('明天下午', history)).shouldSubmit, false);
      final followup = await recovery.plan('后天呢', history);
      expect(followup.text, '后天呢');
      expect(followup.supersedes, isNull);
    },
  );
  test(
    'missing or gapped ledger fails without discarding recovery fact',
    () async {
      final recovery = ConversationTurnRecovery()..started(recoveryCommand());
      recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
      final history = RecoveryFixture()
        ..result = recoveredHistory([
          recoveryFact(2, 'USER_TURN_ACCEPTED', 'original'),
        ]);
      await expectLater(recovery.plan('继续', history), throwsStateError);
      expect(recovery.baseText, '明天下午');
      recovery.clear();
      await expectLater(recovery.plan('继续', history), throwsStateError);
    },
  );
  test('completion and replacement command clear older recovery ownership', () {
    final recovery = ConversationTurnRecovery()..started(recoveryCommand());
    recovery.completed('unrelated');
    recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
    expect(recovery.pending, true);
    recovery.started(recoveryCommand(id: 'new'));
    recovery.completed('new');
    recovery.failed(AgentTransportFailure.network, ordinaryTurn: true);
    expect(recovery.pending, false);
  });
}
