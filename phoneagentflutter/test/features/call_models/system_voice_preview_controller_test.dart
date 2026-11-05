import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/system_voice_preview.dart';
import 'package:phone_agent/features/call_models/presentation/controller/system_voice_preview_controller.dart';

class _Port implements SystemVoicePreviewPort {
  final loads = <String>[];
  final plays = <Uint8List>[];
  Completer<Uint8List>? loading;
  Completer<void>? playing;
  int stops = 0, closes = 0;
  bool failLoad = false, failStop = false;
  @override
  Future<Uint8List> load(String id) async {
    loads.add(id);
    if (failLoad) throw StateError('missing');
    return loading?.future ?? Uint8List.fromList([1, 2]);
  }

  @override
  Future<void> play(Uint8List bytes) async {
    plays.add(bytes);
    playing = Completer<void>();
    await playing!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('cleanup');
    if (playing?.isCompleted == false) playing!.complete();
  }

  @override
  Future<void> close() async {
    closes++;
    await stop();
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('exact native mapping and unknown ID never loads or plays', () async {
    expect(systemVoicePreviewAssets.keys, [
      'Andre',
      'Ethan',
      'Katerina',
      'zh_male_xiaotian_jupiter_bigtts',
      'S_1C6XHhfZ1',
    ]);
    final port = _Port();
    final controller = SystemVoicePreviewController(
      port,
      isCurrent: () => true,
    );
    await controller.toggle('unknown');
    expect(port.loads, isEmpty);
    expect(port.plays, isEmpty);
    controller.dispose();
    await _tick();
  });
  test(
    'toggle stops current; switch serializes audio and completion clears',
    () async {
      final port = _Port();
      final controller = SystemVoicePreviewController(
        port,
        isCurrent: () => true,
      );
      final first = controller.toggle('Andre');
      await _tick();
      expect(controller.state.phase, SystemVoicePreviewPhase.playing);
      final second = controller.toggle('Ethan');
      await _tick();
      await first;
      expect(controller.state.voiceId, 'Ethan');
      expect(port.plays, hasLength(2));
      await controller.toggle('Ethan');
      await second;
      expect(controller.state.phase, SystemVoicePreviewPhase.idle);
      controller.dispose();
      await _tick();
      expect(port.closes, 1);
    },
  );
  test(
    'late asset after stop, dispose or invalid account never plays',
    () async {
      for (final exit in ['stop', 'dispose', 'account']) {
        var current = true;
        final port = _Port()..loading = Completer<Uint8List>();
        final controller = SystemVoicePreviewController(
          port,
          isCurrent: () => current,
        );
        final pending = controller.toggle('Andre');
        await _tick();
        expect(controller.state.phase, SystemVoicePreviewPhase.loading);
        if (exit == 'stop') await controller.stop();
        if (exit == 'dispose') controller.dispose();
        if (exit == 'account') current = false;
        port.loading!.complete(Uint8List.fromList([1]));
        await pending;
        expect(port.plays, isEmpty);
        if (exit != 'dispose') controller.dispose();
        await _tick();
      }
    },
  );
  test(
    'private preview requires explicit policy; failed stop blocks next load',
    () async {
      final port = _Port();
      final controller = SystemVoicePreviewController(
        port,
        isCurrent: () => true,
        supports: (id) => id == cloneCandidatePreviewId || id == 'Ethan',
      );
      final playing = controller.toggle(cloneCandidatePreviewId);
      await _tick();
      expect(port.loads, [cloneCandidatePreviewId]);
      port.failStop = true;
      expect(await controller.stop(), isFalse);
      expect(controller.state.error, '停止试听失败，请重试');
      await controller.toggle('Ethan');
      expect(port.loads, [cloneCandidatePreviewId]);
      port.failStop = false;
      expect(await controller.stop(), isTrue);
      await playing;
      controller.dispose();
      await _tick();
    },
  );
  test('load failure permits explicit retry without auto replay', () async {
    final port = _Port()..failLoad = true;
    final controller = SystemVoicePreviewController(
      port,
      isCurrent: () => true,
    );
    await controller.toggle('Andre');
    expect(controller.state.error, '音色试听失败，请重试');
    expect(port.loads, hasLength(1));
    expect(port.plays, isEmpty);
    port.failLoad = false;
    final retry = controller.toggle('Andre');
    await _tick();
    port.playing!.complete();
    await retry;
    expect(controller.state.phase, SystemVoicePreviewPhase.idle);
    controller.dispose();
    await _tick();
  });
}
