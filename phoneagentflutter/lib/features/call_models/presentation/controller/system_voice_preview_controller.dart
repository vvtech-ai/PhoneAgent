import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/system_voice_preview.dart';

enum SystemVoicePreviewPhase { idle, loading, playing }

class SystemVoicePreviewState {
  const SystemVoicePreviewState({
    this.voiceId = '',
    this.phase = SystemVoicePreviewPhase.idle,
    this.error = '',
  });
  final String voiceId, error;
  final SystemVoicePreviewPhase phase;
}

class SystemVoicePreviewController
    extends StateNotifier<SystemVoicePreviewState> {
  SystemVoicePreviewController(
    this.port, {
    required this.isCurrent,
    bool Function(String)? supports,
  }) : _supports = supports ?? systemVoicePreviewAssets.containsKey,
       super(const SystemVoicePreviewState());
  final SystemVoicePreviewPort port;
  final bool Function() isCurrent;
  final bool Function(String) _supports;
  int _generation = 0;
  Future<void> _stopping = Future.value();

  bool _current(int generation) =>
      mounted && generation == _generation && isCurrent();
  Future<void> _stopAudio() {
    final next = _stopping.then(
      (_) => port.stop(),
      onError: (_) => port.stop(),
    );
    _stopping = next;
    return next;
  }

  Future<void> toggle(String voiceId) async {
    if (!mounted || !isCurrent() || !_supports(voiceId)) {
      return;
    }
    if (state.voiceId == voiceId &&
        state.phase != SystemVoicePreviewPhase.idle) {
      await stop();
      return;
    }
    final generation = ++_generation;
    state = SystemVoicePreviewState(
      voiceId: voiceId,
      phase: SystemVoicePreviewPhase.loading,
    );
    try {
      await _stopAudio();
      if (!_current(generation)) return;
      final bytes = await port.load(voiceId);
      if (!_current(generation)) return;
      state = SystemVoicePreviewState(
        voiceId: voiceId,
        phase: SystemVoicePreviewPhase.playing,
      );
      await port.play(bytes);
      if (_current(generation)) state = const SystemVoicePreviewState();
    } catch (_) {
      if (_current(generation)) {
        state = const SystemVoicePreviewState(error: '音色试听失败，请重试');
      }
    }
  }

  Future<bool> stop() async {
    final generation = ++_generation;
    try {
      await _stopAudio();
      if (_current(generation)) {
        state = const SystemVoicePreviewState();
        return true;
      }
    } catch (_) {
      if (_current(generation)) {
        state = const SystemVoicePreviewState(error: '停止试听失败，请重试');
      }
    }
    return false;
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(
      _stopAudio()
          .then((_) => port.close(), onError: (_) => port.close())
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}
