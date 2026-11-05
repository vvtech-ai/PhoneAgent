import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;
import 'committed_reply_narration_test.dart' show reply, terminal, receipt;

class RejectingSpeechFake extends SpeechFake {
  RejectingSpeechFake(this.cancelBarrier);
  final Future<void>? cancelBarrier;

  @override
  bool enqueue(String text) => false;

  @override
  Future<void> cancel() async {
    if (cancelBarrier != null) await cancelBarrier;
    await super.cancel();
  }
}

class DelayedCancelSpeechFake extends SpeechFake {
  DelayedCancelSpeechFake(this.cancelBarrier);
  final Future<void> cancelBarrier;

  @override
  Future<void> cancel() async {
    await cancelBarrier;
    await super.cancel();
  }
}

void main() {
  late ConversationSpeechController speech;
  late List<SpeechFake> players;
  late List<void Function()> callbacks;
  late bool enabled;
  late List<DiagnosticEvent> diagnostics;
  late DiagnosticTtsNarrationDecision gateDecision;
  late bool failNextHandoff;
  late bool rejectNextAdmission;
  late Completer<void>? rejectedCancelBarrier;
  late Completer<void>? pauseCancelBarrier;
  setUp(() {
    enabled = true;
    diagnostics = [];
    gateDecision = DiagnosticTtsNarrationDecision.gateClosed;
    failNextHandoff = false;
    rejectNextAdmission = false;
    rejectedCancelBarrier = null;
    pauseCancelBarrier = null;
    players = [];
    callbacks = [];
    speech = ConversationSpeechController(
      enabled: () => enabled,
      gateDecision: () => gateDecision,
      diagnostics: diagnostics.add,
      factory: (_, changed) {
        if (failNextHandoff) {
          failNextHandoff = false;
          throw StateError('temporary output handoff failure');
        }
        if (rejectNextAdmission) {
          rejectNextAdmission = false;
          final player = RejectingSpeechFake(rejectedCancelBarrier?.future);
          players.add(player);
          callbacks.add(changed);
          return player;
        }
        if (pauseCancelBarrier != null) {
          final player = DelayedCancelSpeechFake(pauseCancelBarrier!.future);
          pauseCancelBarrier = null;
          players.add(player);
          callbacks.add(changed);
          return player;
        }
        final player = SpeechFake();
        players.add(player);
        callbacks.add(changed);
        return player;
      },
    )..begin(sessionId: 's');
  });
  tearDown(() => speech.dispose());
  void result() {
    speech.accept(terminal());
    speech.results.committed(reply());
    speech.project([reply()], ConversationMessages.project([reply()]));
  }

  void batchResult() {
    speech.waitForBatch('batch');
    final fact = reply(id: 'batch-reply', reason: 'batch_call_result');
    speech.accept(terminal(call: 'batch', batch: true));
    speech.results.committed(fact);
    speech.project([fact], ConversationMessages.project([fact]));
  }

  test('result arrives after done, creates and seals a fresh output', () {
    speech.finish();
    result();
    expect(players.single.sentences, ['持久结果。']);
    expect(players.single.phase, ReplySpeechPhase.draining);
    result();
    expect(players.single.sentences.length, 1);
  });
  test('explicit stop keeps a later batch result silent', () async {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    await speech.pause();

    batchResult();
    expect(players, hasLength(1));
    expect(players.single.sentences, ['正在说明。']);
    expect(
      diagnostics
          .where((event) => event.batchResult != null)
          .last
          .batchResult
          ?.reason,
      DiagnosticBatchResultReason.userStoppedSpeech,
    );
    expect(
      diagnostics.last.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.turnInterrupted,
    );
  });
  test('explicit stop keeps a later single result silent', () async {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    await speech.pause();

    result();
    expect(players, hasLength(1));
    expect(players.single.sentences, ['正在说明。']);
  });
  test('output cancellation keeps a later batch result eligible', () {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    players.single.phase = ReplySpeechPhase.cancelled;
    callbacks.single();

    batchResult();
    expect(players.last.sentences, ['持久结果。']);
  });
  test('output cancellation keeps a later single result eligible', () {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    players.single.phase = ReplySpeechPhase.cancelled;
    callbacks.single();

    result();
    expect(players.last.sentences, ['持久结果。']);
  });
  test('output failure still closes later result eligibility', () {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    players.single.phase = ReplySpeechPhase.failed;
    callbacks.single();

    batchResult();
    expect(players, hasLength(1));
    final gate = diagnostics.where((event) => event.batchResult != null).last;
    expect(
      gate.batchResult?.reason,
      DiagnosticBatchResultReason.playbackFailed,
    );
    expect(
      DiagnosticBatchResultDetails.fromJson(gate.batchResult!.toJson()).reason,
      DiagnosticBatchResultReason.playbackFailed,
    );
  });
  test(
    'lifecycle pause waits to narrate a batch result in foreground',
    () async {
      speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
      speech.setForeground(false);
      await speech.pauseForLifecycle();

      batchResult();
      expect(players, hasLength(1));
      speech.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(players.last.sentences, ['持久结果。']);
      speech.resumeResult();
      expect(players.last.sentences, ['持久结果。']);
    },
  );
  test('foreground result waits until lifecycle audio has stopped', () async {
    final barrier = Completer<void>();
    pauseCancelBarrier = barrier;
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在说明。'));
    speech.setForeground(false);
    final stopping = speech.pauseForLifecycle();
    batchResult();

    speech.setForeground(true);
    await Future<void>.delayed(Duration.zero);
    final playersBeforeRelease = players.length;

    barrier.complete();
    await stopping;
    await Future<void>.delayed(Duration.zero);
    expect(playersBeforeRelease, 1);
    expect(players.last.sentences, ['持久结果。']);
  });
  test('failed batch result output creation retries once', () async {
    failNextHandoff = true;
    batchResult();
    expect(players, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(players.single.sentences, ['持久结果。']);
    speech.resumeResult();
    expect(players.single.sentences, ['持久结果。']);
  });
  test('failed single result output creation also retries once', () async {
    failNextHandoff = true;
    result();
    await Future<void>.delayed(Duration.zero);
    expect(players.single.sentences, ['持久结果。']);
  });
  test('batch result survives a silent output admission rejection', () async {
    rejectNextAdmission = true;
    batchResult();
    await Future<void>.delayed(Duration.zero);
    expect(players, hasLength(2));
    expect(players.last.sentences, ['持久结果。']);
  });
  test('single result survives a silent output admission rejection', () async {
    rejectNextAdmission = true;
    result();
    await Future<void>.delayed(Duration.zero);
    expect(players, hasLength(2));
    expect(players.last.sentences, ['持久结果。']);
  });
  test('rejected output must release before the result retries', () async {
    rejectNextAdmission = true;
    rejectedCancelBarrier = Completer<void>();
    batchResult();
    await Future<void>.delayed(Duration.zero);
    expect(players, hasLength(1));
    rejectedCancelBarrier!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(players.last.sentences, ['持久结果。']);
  });
  test('interruption before the retry keeps the old result silent', () async {
    failNextHandoff = true;
    batchResult();
    await speech.interrupt();
    await Future<void>.delayed(Duration.zero);
    expect(players, isEmpty);
  });
  test('late result waits for previous output actual drain', () {
    speech.accept(const AgentEvent(AgentEventKind.text, text: '前句。'));
    speech.finish();
    result();
    expect(players.single.sentences, ['前句。']);
    players.first.phase = ReplySpeechPhase.completed;
    callbacks.first();
    expect(players.length, 2);
    expect(players.last.sentences, ['持久结果。']);
  });
  test(
    'single call pauses normal speech; projected result resumes only on return',
    () {
      enabled = false;
      speech.pauseForCall();
      speech.finish();
      result();
      expect(players, isEmpty);
      enabled = true;
      speech.resumeResult();
      expect(players.single.sentences, ['持久结果。']);
    },
  );
  test('deferred call without live commit uses synchronized projection', () {
    speech.finish();
    speech.results.deferred('call');
    final facts = [receipt(), reply()];
    speech.project(facts, ConversationMessages.project(facts));
    expect(players.single.sentences, ['持久结果。']);
  });
  test(
    'background cancellation prevents late result restarting playback',
    () async {
      enabled = false;
      speech.pauseForCall();
      result();
      await speech.interrupt();
      enabled = true;
      speech.resumeResult();
      result();
      expect(players, isEmpty);
    },
  );
  test(
    'output failure does not auto retry waiting result; new turn still works',
    () {
      speech.accept(const AgentEvent(AgentEventKind.text, text: '前句。'));
      speech.finish();
      result();
      players.first.phase = ReplySpeechPhase.failed;
      callbacks.first();
      speech.resumeResult();
      expect(players.length, 1);
      speech.begin(sessionId: 's');
      speech.accept(const AgentEvent(AgentEventKind.text, text: '新轮。'));
      expect(players.last.sentences, ['新轮。']);
    },
  );

  test('visible result records an interrupted turn without speaking', () async {
    const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
    speech.begin(sessionId: session);
    await speech.interrupt();
    final fact = reply(session: session, sequence: 25);
    speech.project([fact], ConversationMessages.project([fact]));
    expect(players, isEmpty);
    expect(diagnostics.single.sessionId, session);
    expect(diagnostics.single.ttsNarration?.sequence, 25);
    expect(
      diagnostics.single.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.turnInterrupted,
    );
  });

  test(
    'visible result records the closed gate, then its queue handoff once',
    () {
      const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
      speech.begin(sessionId: session);
      enabled = false;
      gateDecision = DiagnosticTtsNarrationDecision.callActive;
      final fact = reply(session: session, sequence: 25);
      speech.accept(terminal(session: session));
      speech.results.committed(fact);
      speech.project([fact], ConversationMessages.project([fact]));
      speech.project([fact], ConversationMessages.project([fact]));
      expect(diagnostics.map((e) => e.ttsNarration?.decision), [
        DiagnosticTtsNarrationDecision.callActive,
      ]);
      enabled = true;
      speech.resumeResult();
      speech.resumeResult();
      expect(players.single.sentences, ['持久结果。']);
      expect(diagnostics.map((e) => e.ttsNarration?.decision), [
        DiagnosticTtsNarrationDecision.callActive,
        DiagnosticTtsNarrationDecision.queued,
      ]);
    },
  );

  test('already narrated result is not logged again on a later turn', () {
    const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
    speech.begin(sessionId: session);
    final fact = reply(session: session, sequence: 25);
    speech.accept(terminal(session: session));
    speech.results.committed(fact);
    speech.project([fact], ConversationMessages.project([fact]));
    expect(
      diagnostics.single.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.queued,
    );
    speech.begin(sessionId: session);
    speech.project([fact], ConversationMessages.project([fact]));
    expect(diagnostics, hasLength(1));
  });

  test('TTS gate diagnostics deduplicate within a bounded result window', () {
    const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
    speech.begin(sessionId: session);
    for (var i = 0; i < 129; i++) {
      final fact = reply(id: 'reply-$i', sequence: i + 1, session: session);
      final messages = ConversationMessages.project([fact]);
      speech.project([fact], messages);
      speech.project([fact], messages);
    }
    expect(diagnostics, hasLength(129));
    final first = reply(id: 'reply-0', sequence: 1, session: session);
    speech.project([first], ConversationMessages.project([first]));
    speech.project([first], ConversationMessages.project([first]));
    expect(diagnostics, hasLength(130));
  });

  test('visible result distinguishes missing join from prior speech drain', () {
    const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
    speech.begin(sessionId: session);
    final fact = reply(session: session, sequence: 25);
    speech.accept(const AgentEvent(AgentEventKind.text, text: '前句。'));
    speech.finish();
    speech.project([fact], ConversationMessages.project([fact]));
    expect(
      diagnostics.last.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.resultNotMatched,
    );
    speech.accept(terminal(session: session));
    speech.results.committed(fact);
    speech.project([fact], ConversationMessages.project([fact]));
    expect(
      diagnostics.last.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.previousSpeechActive,
    );
    players.first.phase = ReplySpeechPhase.completed;
    callbacks.first();
    expect(
      diagnostics.last.ttsNarration?.decision,
      DiagnosticTtsNarrationDecision.queued,
    );
  });
}
