import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_transcript.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';

void main() {
  test(
    'SSE and polling preserve repeats, bind occurrences and order late segments',
    () {
      var value = CallTranscript()
          .live('a', 2, 'callee：好')
          .live('a', 1, '助手：您好');
      value = value.live('a', 2, 'callee：好');
      expect(value.lines.map((l) => l.text), ['您好', '好']);
      value = value.merge('assistant: 您好\ncallee: 好\ncallee: 好');
      value = value.live('a', 3, 'callee: 好');
      expect(value.lines.map((l) => l.text), ['您好', '好', '好']);
      expect(value.lines.map((l) => l.segmentIndex), [1, 2, 3]);
      expect(value.merge('assistant: 您好').lines.length, 3);
    },
  );
  test('polling prefix arriving after later SSE segment keeps chronology', () {
    var value = CallTranscript().live('a', 2, 'callee: 第二句');
    value = value.merge('assistant: 第一句\ncallee: 第二句');
    expect(value.lines.map((l) => l.text), ['第一句', '第二句']);
    var prefix = CallTranscript().live('a', 3, 'callee: 第三句');
    prefix = prefix.merge('assistant: 第一句\ncallee: 第二句');
    expect(prefix.lines.map((l) => l.text), ['第一句', '第二句', '第三句']);
  });
  test('snapshot prefix keeps a repeated utterance before later SSE', () {
    final value = CallTranscript().live('a', 2, 'callee: 好').merge('callee: 好');
    expect(value.lines.map((l) => l.text), ['好', '好']);
    expect(value.lines.map((l) => l.segmentIndex), [null, 2]);
    final completed = value.live('a', 1, 'callee: 好');
    expect(completed.lines.map((l) => l.segmentIndex), [1, 2]);
  });
  test('snapshot matches SSE positions after an unprefixed continuation', () {
    final value = CallTranscript()
        .live('a', 1, 'assistant: 您好')
        .live('a', 2, 'assistant: 说明')
        .live('a', 3, 'callee: 好')
        .merge('assistant: 您好\n说明\nmerchant: 好');
    expect(value.lines.map((l) => l.text), ['您好', '说明', '好']);
    expect(value.lines.map((l) => l.segmentIndex), [1, 2, 3]);
  });
  test('late SSE binds the snapshot row after an unprefixed continuation', () {
    var value = CallTranscript().merge('assistant: 您好\n说明\nmerchant: 好');
    value = value.live('a', 3, 'callee: 好');
    expect(value.lines.map((l) => l.text), ['您好', '好']);
    value = value.live('a', 2, 'assistant: 说明');
    expect(value.lines.map((l) => l.text), ['您好', '说明', '好']);
    expect(value.lines.map((l) => l.segmentIndex), [null, 2, 3]);
  });
  test('snapshot keeps normal SSE order across an unprefixed continuation', () {
    var value = CallTranscript().merge('assistant: 您好\n说明\nmerchant: 好');
    value = value.live('a', 1, 'assistant: 您好');
    value = value.live('a', 2, 'assistant: 说明');
    value = value.live('a', 3, 'callee: 好');
    expect(value.lines.map((l) => l.text), ['您好', '说明', '好']);
    expect(value.lines.map((l) => l.segmentIndex), [1, 2, 3]);
  });
  test('identical continuation and snapshot speech keep three positions', () {
    var value = CallTranscript().merge('assistant: 好\n好\nassistant: 好');
    value = value.live('a', 1, 'assistant: 好');
    value = value.live('a', 2, 'assistant: 好');
    value = value.live('a', 3, 'assistant: 好');
    expect(value.lines.map((l) => l.text), ['好', '好', '好']);
    expect(value.lines.map((l) => l.segmentIndex), [1, 2, 3]);
  });
  test('polling inserts the first row before a later continuation SSE', () {
    var value = CallTranscript()
        .live('a', 2, 'assistant: 说明')
        .merge('assistant: 您好\n说明\nmerchant: 好');
    expect(value.lines.map((l) => l.text), ['您好', '说明', '好']);
    value = value.live('a', 3, 'callee: 好');
    expect(value.lines.map((l) => l.segmentIndex), [null, 2, 3]);
  });
  test(
    'identical speech arriving out of order binds distinct numbered occurrences',
    () {
      var value = CallTranscript()
          .live('a', 2, 'callee: 好')
          .merge('callee: 好\ncallee: 好');
      value = value.live('a', 1, 'callee: 好').live('a', 3, 'callee: 好');
      expect(value.lines.map((l) => l.segmentIndex), [1, 2, 3]);
      expect(value.lines.map((l) => l.text), ['好', '好', '好']);
    },
  );
  testWidgets('polling prefix keeps a repeated live caption in the call', (
    tester,
  ) async {
    final repo = _Calls();
    final c = CallSessionController(
      conversationId: 's',
      target: CallSessionTarget(taskId: 's'),
      repository: repo,
    );
    addTearDown(c.dispose);
    c.start();
    await tester.pump();
    expect(c.bindStarted('c', attemptId: 'a'), true);
    await tester.pump();
    expect(
      c.acceptProgress(
        'a',
        'callee: 好',
        outcomePush: false,
        captionFinal: true,
        segmentIndex: 2,
      ),
      true,
    );
    repo.dialogueDetail = 'callee: 好';
    await c.refresh();
    expect(c.snapshot.transcript.lines.map((l) => l.text), ['好', '好']);
    expect(c.snapshot.transcript.lines.map((l) => l.segmentIndex), [null, 2]);
    c.close();
  });
  testWidgets(
    'hangup acknowledgment keeps polling and blocks repeated hangup until terminal',
    (tester) async {
      final repo = _Calls();
      final c = CallSessionController(
        conversationId: 's',
        target: CallSessionTarget(taskId: 's'),
        repository: repo,
      );
      addTearDown(c.dispose);
      c.start();
      await tester.pump();
      expect(c.snapshot.canHangUp, true);
      expect(await c.hangUp(), true);
      expect(c.snapshot.ending, true);
      expect(c.snapshot.dismissRequested, false);
      expect(await c.hangUp(), false);
      repo.ended = true;
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(c.snapshot.phase, CallSessionPhase.awaitingOutcome);
      expect(repo.hangups, 1);
    },
  );
  testWidgets(
    'old status is ignored; call ID and attempt ID bind early captions independently',
    (tester) async {
      final repo = _Calls()..id = 'old';
      final c = CallSessionController(
        conversationId: 's',
        target: CallSessionTarget(taskId: 's'),
        repository: repo,
        excludedCallIds: {'old'},
      );
      addTearDown(c.dispose);
      c.start();
      c.acceptProgress(
        'prior-attempt',
        'assistant: 旧字幕',
        outcomePush: false,
        captionFinal: true,
        segmentIndex: 1,
      );
      c.acceptProgress(
        'attempt',
        'assistant: 新字幕',
        outcomePush: false,
        captionFinal: true,
        segmentIndex: 1,
      );
      await tester.pump();
      expect(c.snapshot.target.callId, isEmpty);
      repo.id = 'new';
      expect(c.bindStarted('new', attemptId: 'attempt'), true);
      await tester.pump();
      expect(c.snapshot.transcript.lines.single.text, '新字幕');
      expect(
        c.acceptProgress(
          'old',
          'assistant: 迟到',
          outcomePush: true,
          captionFinal: true,
          segmentIndex: 2,
        ),
        false,
      );
      c.close();
    },
  );
}

class _Calls implements CallSessionRepository {
  String id = 'c';
  String dialogueDetail = '';
  int hangups = 0;
  bool ended = false;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async =>
      CallSessionSnapshot(
        callId: id,
        taskId: 's',
        callState: ended ? 'ENDED' : 'CONNECTED',
        handoffMode: ended ? 'COMPLETED' : '',
        dialogueDetail: dialogueDetail,
      );
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    hangups++;
    return status(target);
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) async =>
      throw UnimplementedError();
}
