import 'package:flutter/material.dart';
import '../../../../../core/design/receipt_tokens.dart';
import '../../../../translation_history/presentation/controller/recording_audio_controller.dart';
import '../../../../translation_history/presentation/widgets/recording_audio_card.dart';
import '../../../../translation_history/presentation/widgets/native_recording_waveform.dart';
import 'native_compact_recording_glyph.dart';

/// Shared receipt presentation. No repository, audio or provider access here.
class CallRecordingControl extends StatefulWidget {
  const CallRecordingControl({
    super.key,
    required this.state,
    required this.compact,
    required this.onPrimary,
    required this.onSave,
    this.saving,
  });
  final RecordingAudioState state;
  final bool compact;
  final VoidCallback onPrimary, onSave;
  final bool? saving;

  @override
  State<CallRecordingControl> createState() => _CallRecordingControlState();
}

class _CallRecordingControlState extends State<CallRecordingControl> {
  List<double>? _lastFrame;

  @override
  void initState() {
    super.initState();
    _rememberFrame();
  }

  @override
  void didUpdateWidget(covariant CallRecordingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberFrame();
  }

  void _rememberFrame() {
    if (widget.state.phase == RecordingAudioPhase.playing) {
      if (widget.state.waveform case final levels?) {
        _lastFrame = List.unmodifiable(levels);
      }
    } else if (widget.state.phase != RecordingAudioPhase.paused) {
      _lastFrame = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final onPrimary = widget.onPrimary, onSave = widget.onSave;
    if (!widget.compact) {
      final view = widget.saving == null
          ? state
          : RecordingAudioState(
              phase: state.phase,
              busy: state.busy,
              retrying: state.retrying,
              saving: widget.saving!,
              positionMillis: state.positionMillis,
              durationMillis: state.durationMillis,
              message: state.message,
            );
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReceiptTokens.singleWidth,
          ),
          child: RecordingAudioCard(
            state: view,
            onPrimary: onPrimary,
            onSave: onSave,
            loadOnAction: true,
            allowPlaybackWhileSaving: true,
            waveform:
                _lastFrame ?? NativeRecordingWaveformPainter.defaultLevels,
            outerPadding: const EdgeInsets.only(bottom: 8),
          ),
        ),
      );
    }
    final loading =
        state.busy ||
        const {
          RecordingAudioPhase.loading,
          RecordingAudioPhase.processing,
        }.contains(state.phase);
    final playing = state.phase == RecordingAudioPhase.playing;
    final failed = state.phase == RecordingAudioPhase.failed;
    return IconButton(
      key: const ValueKey('receipt-recording-play'),
      tooltip: loading
          ? '录音加载中'
          : failed
          ? '录音加载失败，重新加载'
          : playing
          ? '暂停本次电话录音'
          : '播放本次电话录音',
      onPressed: loading ? null : onPrimary,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF0A84FF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: loading
              ? const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                )
              : NativeCompactRecordingGlyph(
                  shape: failed
                      ? NativeCompactRecordingShape.retry
                      : playing
                      ? NativeCompactRecordingShape.pause
                      : NativeCompactRecordingShape.play,
                ),
        ),
      ),
    );
  }
}
