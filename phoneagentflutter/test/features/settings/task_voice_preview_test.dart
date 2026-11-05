import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/features/settings/presentation/controller/task_voice_preview_controller.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';

class Playback implements ReplySpeechPlayback {
  Playback(this.changed);
  final void Function() changed;
  int stops = 0;
  Completer<void>? stopping;
  final texts = <String>[];
  @override
  ReplySpeechPhase phase = ReplySpeechPhase.accepting;
  @override
  int failures = 0;
  @override
  int get queuedBytes => 0;
  @override
  bool get synthesizing => false;
  @override
  bool get hasPendingText => false;
  @override
  bool enqueue(String text) {
    texts.add(text);
    return true;
  }

  @override
  void complete() {}
  @override
  Future<void> cancel() async {
    stops++;
    await stopping?.future;
    phase = ReplySpeechPhase.cancelled;
    changed();
  }
}

void main() {
  test('switch waits for stop, same row stops, failure is retryable', () async {
    final players = <Playback>[];
    final voices = <TaskVoice>[];
    final c = TaskVoicePreviewController(
      (voice) => (current, changed) {
        voices.add(voice);
        final p = Playback(changed);
        players.add(p);
        return p;
      },
    );
    await c.toggle(TaskVoice.maia);
    expect(players.single.texts.single, '你好，我是你的 AI 助理，有什么能帮到你？');
    players.single.stopping = Completer();
    final switching = c.toggle(TaskVoice.andre);
    await Future<void>.delayed(Duration.zero);
    expect(players, hasLength(1));
    players.first.stopping!.complete();
    await switching;
    expect(voices, [TaskVoice.maia, TaskVoice.andre]);
    players.last.failures = 1;
    players.last.changed();
    expect(c.state.error, isNotEmpty);
    await c.toggle(TaskVoice.andre);
    expect(players, hasLength(3));
    await c.toggle(TaskVoice.andre);
    expect(c.state.voice, isNull);
    c.dispose();
  });
  test('stop during pending switch suppresses new playback', () async {
    final players = <Playback>[];
    final c = TaskVoicePreviewController(
      (voice) => (current, changed) {
        final p = Playback(changed);
        players.add(p);
        return p;
      },
    );
    await c.toggle(TaskVoice.maia);
    players.first.stopping = Completer();
    final switching = c.toggle(TaskVoice.andre);
    final stopped = c.stop();
    players.first.stopping!.complete();
    await switching;
    await stopped;
    expect(players, hasLength(1));
    expect(c.state.voice, isNull);
    c.dispose();
  });
}
