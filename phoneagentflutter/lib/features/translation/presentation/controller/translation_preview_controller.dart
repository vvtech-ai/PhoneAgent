import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/translation_call_view.dart';

/// UI-only simulator, deliberately no API/media/account dependencies.
/// This is not the production create/media-ready/merchant-call coordinator.
class TranslationPreviewController extends StateNotifier<TranslationCallView> {
  TranslationPreviewController({
    this.failPreflight = false,
    this.failHangup = false,
  }) : super(const TranslationCallView());
  final bool failPreflight, failHangup;
  bool _hangupFailed = false;
  Timer? _timer;
  TranslationCallView get snapshot => state;
  void advance() {
    if (!mounted || state.terminal) return;
    if (state.phase == TranslationPhase.preflight && failPreflight) {
      state = state.copy(
        phase: TranslationPhase.failed,
        error: 'MOCK · 通话环境检查失败',
      );
      return;
    }
    final next = switch (state.phase) {
      TranslationPhase.preflight => TranslationPhase.dialing,
      TranslationPhase.dialing => TranslationPhase.ringing,
      TranslationPhase.ringing => TranslationPhase.connected,
      TranslationPhase.connected => TranslationPhase.translating,
      _ => state.phase,
    };
    state = state.copy(phase: next);
    if (next == TranslationPhase.connected && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !state.terminal) {
          state = state.copy(elapsedSeconds: state.elapsedSeconds + 1);
        }
      });
    }
  }

  void mute() {
    if (mounted && !state.terminal) state = state.copy(muted: !state.muted);
  }

  void speaker() {
    if (mounted && !state.terminal) state = state.copy(speaker: !state.speaker);
  }

  void dialPad() {
    if (mounted && !state.terminal) state = state.copy(dialPad: !state.dialPad);
  }

  void digit(String digit) {
    if (!mounted ||
        state.terminal ||
        !state.dialPad ||
        !RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      return;
    }
    final value = '${state.dtmf}$digit';
    state = state.copy(
      dtmf: value.length > 16 ? value.substring(value.length - 16) : value,
    );
  }

  void transcript(TranslationTranscript item) {
    if (!mounted ||
        state.terminal ||
        state.phase != TranslationPhase.translating) {
      return;
    }
    final items = [...state.transcripts];
    final index = items.indexWhere((row) => row.key == item.key);
    if (index < 0) {
      items.add(item);
    } else {
      if (items[index].isFinal && !item.isFinal) return;
      items[index] = item;
    }
    state = state.copy(transcripts: List.unmodifiable(items));
  }

  void hangup() {
    if (!mounted || state.terminal) return;
    if (failHangup && !_hangupFailed) {
      _hangupFailed = true;
      state = state.copy(error: 'MOCK · 挂断失败，请确认状态后再次点击');
      return;
    }
    end();
  }

  void end() {
    if (!mounted || state.terminal) return;
    _timer?.cancel();
    state = state.copy(phase: TranslationPhase.ended);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
