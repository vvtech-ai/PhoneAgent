import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/voice/manual_voice_transcript.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'voice_input_fake.dart';
import 'package:phone_agent/features/conversation/domain/voice/spoken_phone_number.dart';

void main() {
  test('v66 spoken phone digits retain name, context and ordinary numbers', () {
    expect(
      SpokenPhoneNumber.normalize('姓王，手机号是一三八零零一三八零零零。'),
      '姓王，手机号是13800138000。',
    );
    expect(SpokenPhoneNumber.normalize('尾号幺，二、三，四。'), '尾号1234。');
    expect(SpokenPhoneNumber.normalize('幺三八零零幺三八零零零'), '13800138000');
    expect(SpokenPhoneNumber.normalize('王二，明天七点三个人'), '王二，明天七点三个人');
    final transcript = ManualVoiceTranscript()
      ..partial('手机号是一三八零')
      ..finalText('手机号是一三八零零一三八零零零。');
    expect(transcript.releaseText, '手机号是13800138000。');
    expect(transcript.timeoutText, transcript.releaseText);
  });
  late InputPermissionFake permission;
  late List<VoiceInputFake> sessions;
  late List<String> sent;
  late VoiceInputController input;
  bool current = true, canSend = true;
  String recoveryText = '';
  setUp(() {
    current = canSend = true;
    recoveryText = '';
    permission = InputPermissionFake();
    sessions = [];
    sent = [];
    input = VoiceInputController(
      createSession: () {
        final session = VoiceInputFake();
        sessions.add(session);
        return session;
      },
      permissions: permission,
      endpoint: Uri.parse('wss://synthetic.invalid/asr'),
      isCurrent: () => current,
      canSubmit: () => canSend,
      recoveryText: () => recoveryText,
      submit: (text) {
        sent.add(text);
        return true;
      },
    );
  });
  tearDown(() {
    input.dispose();
  });
  void start(FakeAsync time) {
    unawaited(input.press());
    time.flushMicrotasks();
    sessions.last.emit(const VoiceReady());
  }

  test('spoken phone partial becomes one normalized submitted user turn', () {
    fakeAsync((time) {
      start(time);
      sessions.last.emit(const VoiceTranscript('手机号是一三八零', isFinal: false));
      expect(input.state.text, '手机号是1380');
      input.release();
      sessions.last.emit(
        const VoiceTranscript('手机号是一三八零零一三八零零零。', isFinal: true),
      );
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 2));
      time.flushMicrotasks();
      expect(sent, ['手机号是13800138000。']);
      expect(input.state.text, isEmpty);
    });
  });

  test('overlap, cumulative and independent final clauses match v65', () {
    expect(ManualVoiceTranscript.merge('明天', '明天下午'), '明天下午');
    expect(ManualVoiceTranscript.merge('明天下午', '下午开会'), '明天下午开会');
    expect(ManualVoiceTranscript.merge('明天下午', '下午'), '明天下午');
    expect(ManualVoiceTranscript.merge('明天开会', '后天休息'), '明天开会 后天休息');
    final text = ManualVoiceTranscript()
      ..finalText('明天')
      ..partial('明天下午');
    expect(text.releaseText, '明天下午');
    expect(text.timeoutText, '明天下午');
    expect(text.finalText('qwen-asrv1.0'), false);
  });
  test(
    'recovery prefix is read at press and merged; cancel never submits it',
    () {
      fakeAsync((time) {
        recoveryText = '明天下午';
        start(time);
        expect(input.state.text, '明天下午');
        sessions.last.emit(const VoiceTranscript('下午开会', isFinal: false));
        expect(input.state.text, '明天下午开会');
        unawaited(input.cancel());
        time.flushMicrotasks();
        expect(sent, isEmpty);
        start(time);
        input.release();
        sessions.last.emit(const VoiceTranscript('下午开会', isFinal: true));
        time.flushMicrotasks();
        expect(sent, ['明天下午开会']);
      });
    },
  );
  test(
    'hold buffers finals; release continues capture until valid final once',
    () {
      fakeAsync((time) {
        start(time);
        sessions.last.emit(const VoiceTranscript('明天', isFinal: true));
        expect(sent, isEmpty);
        input.release();
        expect(sessions.last.releases, 0);
        expect(sessions.last.stops, 0);
        sessions.last.emit(
          const VoiceTranscript('qwen-asrv1.0', isFinal: true),
        );
        expect(input.state.phase, VoiceInputPhase.finalizing);
        sessions.last.emit(const VoiceTranscript('明天下午', isFinal: true));
        sessions.last.emit(const VoiceTranscript('重复', isFinal: true));
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 3));
        expect(sent, ['明天下午']);
        expect(sessions.last.stops, 1);
      });
    },
  );
  test(
    'fallback clears only unconfirmed partial, keeps tail and submits once',
    () {
      fakeAsync((time) {
        start(time);
        sessions.last.emit(const VoiceTranscript('明天', isFinal: true));
        sessions.last.emit(const VoiceTranscript('错误片段', isFinal: false));
        input.release();
        sessions.last.emit(const VoiceRecognitionFallback());
        expect(input.state.phase, VoiceInputPhase.finalizing);
        expect(input.state.text, '明天');
        expect(input.state.notice, '正在切换备用语音识别');
        sessions.last.emit(const VoiceReady());
        expect(input.state.phase, VoiceInputPhase.finalizing);
        sessions.last.emit(const VoiceTranscript('明天下午', isFinal: true));
        sessions.last.emit(const VoiceTranscript('重复', isFinal: true));
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 3));
        expect(sent, ['明天下午']);
      });
    },
  );

  test('two second deadline merges final and newest partial', () {
    fakeAsync((time) {
      start(time);
      sessions.last.emit(const VoiceTranscript('明天', isFinal: true));
      input.release();
      sessions.last.emit(const VoiceTranscript('明天开会', isFinal: false));
      time.elapse(const Duration(milliseconds: 1999));
      expect(sent, isEmpty);
      time.elapse(const Duration(milliseconds: 1));
      expect(sent, ['明天开会']);
    });
  });
  test('60 second hold auto submits best transcript once', () {
    fakeAsync((time) {
      start(time);
      sessions.last.emit(const VoiceTranscript('明天开会', isFinal: false));
      time.elapse(const Duration(seconds: 60));
      input.release();
      time.elapse(const Duration(seconds: 3));
      expect(sent, ['明天开会']);
    });
  });
  test('empty tail shows retry without creating Agent message', () {
    fakeAsync((time) {
      start(time);
      input.release();
      time.elapse(const Duration(seconds: 2));
      expect(sent, isEmpty);
      expect(input.state.notice, contains('未识别'));
    });
  });
  test('ready arriving during tail cannot reopen holding state', () {
    fakeAsync((time) {
      unawaited(input.press());
      time.flushMicrotasks();
      input.release();
      sessions.last.emit(const VoiceReady());
      expect(input.state.phase, VoiceInputPhase.finalizing);
      time.elapse(const Duration(seconds: 2));
      expect(sessions.last.stops, 1);
    });
  });
  test('cancel rejects late result and old connection after next press', () {
    fakeAsync((time) {
      start(time);
      final old = sessions.last;
      unawaited(input.cancel());
      time.flushMicrotasks();
      start(time);
      old.emit(const VoiceTranscript('旧内容', isFinal: true));
      input.release();
      time.elapse(const Duration(seconds: 2));
      expect(sent, isEmpty);
      expect(sessions.length, 2);
    });
  });
  test('release while permission pending never starts on late grant', () {
    fakeAsync((time) {
      permission.gate = Completer<PermissionGrant>();
      unawaited(input.press());
      time.flushMicrotasks();
      input.release();
      permission.gate!.complete(PermissionGrant.granted);
      time.flushMicrotasks();
      expect(sessions, isEmpty);
      expect(sent, isEmpty);
    });
  });
  test('permission denial requests once and reports actionable state', () {
    fakeAsync((time) {
      permission.grant = PermissionGrant.denied;
      unawaited(input.press());
      time.flushMicrotasks();
      expect(permission.requests, [false, true]);
      expect(sessions, isEmpty);
      expect(input.state.phase, VoiceInputPhase.failed);
    });
  });
  test('server failure does not submit potentially incomplete partial', () {
    fakeAsync((time) {
      start(time);
      sessions.last.emit(const VoiceTranscript('片段', isFinal: false));
      sessions.last.emit(const VoiceGatewayFailure('synthetic'));
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 3));
      expect(sent, isEmpty);
      expect(input.state.notice, contains('中断'));
    });
  });
  test(
    'must await actual stop before submit and cancel while stopping wins',
    () {
      fakeAsync((time) {
        start(time);
        sessions.last.stopGate = Completer<void>();
        input.release();
        sessions.last.emit(const VoiceTranscript('安排', isFinal: true));
        time.flushMicrotasks();
        expect(sent, isEmpty);
        unawaited(input.cancel());
        time.flushMicrotasks();
        sessions.last.stopGate!.complete();
        time.flushMicrotasks();
        expect(sent, isEmpty);
        expect(sessions.last.stops, 1);
      });
    },
  );
  test(
    'failed stop keeps resource and new press retries before new session',
    () {
      fakeAsync((time) {
        start(time);
        final old = sessions.last;
        old.failStop = true;
        input.release();
        old.emit(const VoiceTranscript('安排', isFinal: true));
        time.flushMicrotasks();
        expect(input.state.phase, VoiceInputPhase.failed);
        expect(sent, isEmpty);
        old.failStop = false;
        unawaited(input.press());
        time.flushMicrotasks();
        expect(old.stops, 2);
        expect(sessions.length, 2);
        unawaited(input.cancel());
        time.flushMicrotasks();
      });
    },
  );
  test('changed conversation or admission rejects completion', () {
    fakeAsync((time) {
      start(time);
      canSend = false;
      input.release();
      sessions.last.emit(const VoiceTranscript('安排', isFinal: true));
      time.flushMicrotasks();
      expect(sent, isEmpty);
      expect(input.state.notice, contains('无法提交'));
      current = false;
      unawaited(input.press());
      time.flushMicrotasks();
      expect(sessions.length, 1);
    });
  });
  test('dispose during tail never submits and releases once', () {
    fakeAsync((time) {
      start(time);
      input.release();
      input.dispose();
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 3));
      expect(sent, isEmpty);
      expect(sessions.last.stops, 1);
      // Avoid double-dispose in tearDown.
      input = VoiceInputController(
        createSession: VoiceInputFake.new,
        permissions: permission,
        endpoint: null,
        isCurrent: () => false,
        canSubmit: () => false,
        submit: (_) => false,
      );
    });
  });
  test(
    'ordinary Web entry does not create session or request permission',
    () async {
      input.dispose();
      input = VoiceInputController(
        createSession: () => throw StateError('must not create'),
        permissions: permission,
        endpoint: Uri.parse('wss://synthetic.invalid/asr'),
        isCurrent: () => true,
        canSubmit: () => true,
        submit: (_) => throw StateError('must not submit'),
        available: false,
      );
      await input.press();
      expect(permission.requests, isEmpty);
      expect(input.state.notice, contains('Web 请使用文字输入'));
    },
  );
}
