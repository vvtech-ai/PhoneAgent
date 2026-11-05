import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/features/settings/presentation/controller/task_voice_controller.dart';

class Store implements TaskVoiceStore {
  TaskVoice value = TaskVoice.maia;
  bool fail = false;
  Completer<void>? saving;
  @override
  Future<TaskVoice> read() async {
    if (fail) throw StateError('read');
    return value;
  }

  @override
  Future<void> write(TaskVoice voice) async {
    await saving?.future;
    if (fail) throw StateError('write');
    value = voice;
  }
}

void main() {
  test(
    'load failure retries and selection persists only after successful write',
    () async {
      final store = Store()..fail = true;
      final c = TaskVoiceController(store);
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.ready, isFalse);
      store.fail = false;
      await c.load();
      store.saving = Completer();
      final pending = c.select(TaskVoice.andre);
      expect(c.state.voice, TaskVoice.maia);
      expect(c.state.busy, isTrue);
      await c.select(TaskVoice.maia);
      store.saving!.complete();
      await pending;
      expect(c.state.voice, TaskVoice.andre);
      final restored = TaskVoiceController(store);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.state.voice, TaskVoice.andre);
      store.fail = true;
      await c.select(TaskVoice.maia);
      expect(c.state.voice, TaskVoice.andre);
      expect(c.state.error, isNotEmpty);
    },
  );
}
