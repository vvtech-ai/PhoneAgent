import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_voice_preference_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_voice_guide_controller.dart';

class _Preferences implements TaskVoicePreferenceRepository {
  TaskVoicePreferences value = const TaskVoicePreferences(speechEnabled: false);
  bool failRead = false, failGuide = false;
  int completions = 0;
  @override
  Future<TaskVoicePreferences> read() async {
    if (failRead) throw StateError('read');
    return value;
  }

  @override
  Future<void> speech(bool enabled) async {
    value = TaskVoicePreferences(speechEnabled: enabled);
  }

  @override
  Future<void> completeGuide() async {
    completions++;
    if (failGuide) throw StateError('write');
  }
}

void main() {
  testWidgets(
    'initial guide waits for welcome, short reminder expires and press cancels timer',
    (tester) async {
      final pref = TaskVoicePreferenceController(_Preferences());
      await pref.load();
      final guide = TaskVoiceGuideController(pref);
      guide.ready(false);
      expect(guide.hint, isEmpty);
      guide.ready(true);
      expect(guide.hint, '按住说话');
      await tester.pump(const Duration(seconds: 4));
      expect(guide.hint, '按住说话');
      guide.press(Duration.zero);
      guide.release(const Duration(milliseconds: 50));
      expect(guide.hint, '请按住说话，说完松开');
      await tester.pump(const Duration(milliseconds: 2999));
      expect(guide.hint, isNotEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(guide.hint, isEmpty);
      guide.ready(true);
      expect(guide.hint, isEmpty);
      expect(pref.guideCompleted, isFalse);
      guide.dispose();
      final next = TaskVoiceGuideController(pref);
      next.ready(true);
      next.press(Duration.zero);
      next.release(const Duration(milliseconds: 50));
      next.press(const Duration(seconds: 1));
      expect(next.hint, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      expect(next.hint, isEmpty);
      next.dispose();
      pref.dispose();
    },
  );
  test(
    'read failure stays unavailable, retry restores persisted playback switch',
    () async {
      final store = _Preferences()..failRead = true;
      final c = TaskVoicePreferenceController(store);
      await c.load();
      expect(c.ready, isFalse);
      expect(c.notice, isNotEmpty);
      store.failRead = false;
      await c.load();
      expect(c.ready, isTrue);
      expect(c.speechEnabled, isFalse);
      expect(c.notice, isEmpty);
      c.speech(true);
      await Future<void>.delayed(Duration.zero);
      expect((await store.read()).speechEnabled, isTrue);
      c.dispose();
    },
  );
  test(
    'first hint, short taps, cancellation and accepted gesture follow v66',
    () {
      final p = VoiceGuidePolicy();
      p.ready(false, false);
      expect(p.hint, isEmpty);
      p.ready(false, true);
      expect(p.hint, '按住说话');
      p.press(Duration.zero);
      expect(p.hint, isEmpty);
      expect(p.release(const Duration(milliseconds: 299), false), isFalse);
      expect(p.hint, '请按住说话，说完松开');
      expect(p.accepted(), isFalse);
      p.press(const Duration(seconds: 1));
      expect(p.release(const Duration(milliseconds: 1300), false), isTrue);
      p.cancel();
      expect(p.accepted(), isFalse);
      p.press(const Duration(seconds: 2));
      expect(p.release(const Duration(seconds: 3), false), isTrue);
      expect(p.accepted(), isTrue);
      expect(p.accepted(), isFalse);
      final done = VoiceGuidePolicy();
      done.ready(true, true);
      expect(done.hint, isEmpty);
      for (var n = 0; n < 2; n++) {
        done.press(Duration(seconds: n));
        expect(
          done.release(Duration(milliseconds: n * 1000 + 50), true),
          isFalse,
        );
        expect(done.hint.isNotEmpty, n == 1);
      }
    },
  );
  test(
    'only accepted effective gesture persists completion; failed write does not claim success',
    () async {
      final store = _Preferences()..failGuide = true;
      final pref = TaskVoicePreferenceController(store);
      await pref.load();
      final guide = TaskVoiceGuideController(pref);
      guide.press(Duration.zero);
      guide.cancel();
      guide.accepted();
      expect(store.completions, 0);
      guide.press(Duration.zero);
      guide.release(const Duration(seconds: 1));
      guide.accepted();
      await Future<void>.delayed(Duration.zero);
      expect(pref.guideCompleted, isFalse);
      store.failGuide = false;
      guide.press(const Duration(seconds: 2));
      guide.release(const Duration(seconds: 3));
      guide.accepted();
      await Future<void>.delayed(Duration.zero);
      expect(pref.guideCompleted, isTrue);
      guide.dispose();
      guide.accepted();
      guide.press(Duration.zero);
      expect(guide.release(Duration.zero), isFalse);
      pref.dispose();
    },
  );
}
