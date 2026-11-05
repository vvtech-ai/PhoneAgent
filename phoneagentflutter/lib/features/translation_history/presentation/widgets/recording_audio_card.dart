import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/design/recording_tokens.dart';
import '../controller/recording_audio_controller.dart';
import 'native_recording_waveform.dart';

/// Pure presentation. Audio events and export never originate in this widget.
class RecordingAudioCard extends StatelessWidget {
  const RecordingAudioCard({
    super.key,
    required this.state,
    required this.onPrimary,
    required this.onSave,
    this.loadOnAction = false,
    this.allowPlaybackWhileSaving = false,
    this.waveform,
    this.outerPadding = RecordingTokens.outerPadding,
  });
  final RecordingAudioState state;
  final VoidCallback onPrimary, onSave;
  final bool loadOnAction;
  final bool allowPlaybackWhileSaving;
  final List<double>? waveform;
  final EdgeInsetsGeometry outerPadding;

  @override
  Widget build(BuildContext context) {
    final phase = state.phase;
    final pending =
        phase == RecordingAudioPhase.loading ||
        phase == RecordingAudioPhase.processing;
    final failed = phase == RecordingAudioPhase.failed;
    final compact = failed || state.retrying;
    final primaryLabel = state.retrying
        ? '音频加载失败'
        : pending || state.busy
        ? '录音加载中'
        : failed
        ? '重试加载录音'
        : phase == RecordingAudioPhase.playing
        ? '暂停录音'
        : '播放录音';
    return Padding(
      padding: outerPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              minHeight: compact
                  ? RecordingTokens.failureMinHeight
                  : RecordingTokens.minHeight,
            ),
            padding: compact
                ? RecordingTokens.failurePadding
                : RecordingTokens.innerPadding,
            decoration: BoxDecoration(
              color: RecordingTokens.blue,
              borderRadius: BorderRadius.circular(
                compact
                    ? RecordingTokens.failureRadius
                    : RecordingTokens.radius,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x29000000),
                  blurRadius: compact ? 4 : 8,
                  offset: Offset(0, compact ? 2 : 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleFont = compact ? 12.0 : 17.0;
                final titleWidth =
                    (compact ? 66 : 84) *
                    MediaQuery.textScalerOf(context).scale(titleFont) /
                    titleFont;
                final inline =
                    constraints.maxWidth >= titleWidth + (compact ? 142 : 150);
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通话录音',
                      style: compact
                          ? RecordingTokens.failureTitle
                          : RecordingTokens.title,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      compact
                          ? '音频加载失败'
                          : pending
                          ? '录音加载中'
                          : loadOnAction && state.durationMillis == 0
                          ? '点击播放'
                          : state.remaining,
                      style: compact
                          ? RecordingTokens.failureSubtitle
                          : RecordingTokens.subtitle,
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _action(
                          IconButton(
                            key: const ValueKey('recording-save'),
                            tooltip: '保存录音',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed:
                                state.saving ||
                                    phase == RecordingAudioPhase.processing ||
                                    (state.busy && !pending)
                                ? null
                                : onSave,
                            icon: _saveGlyph(
                              compact,
                              state.saving ||
                                  (phase == RecordingAudioPhase.loading &&
                                      !state.retrying),
                            ),
                          ),
                        ),

                        SizedBox(width: compact ? 3 : 6),
                        if (inline)
                          SizedBox(width: titleWidth, child: title)
                        else
                          Expanded(child: title),
                        if (inline) ...[
                          SizedBox(width: compact ? 4 : 6),
                          Expanded(
                            child: NativeRecordingWaveform(
                              levels: waveform,
                              playing: phase == RecordingAudioPhase.playing,
                              paused: phase == RecordingAudioPhase.paused,
                              height: compact ? 30 : 38,
                            ),
                          ),
                          SizedBox(width: compact ? 7 : 8),
                        ],
                        _action(
                          IconButton(
                            key: const ValueKey('recording-primary'),
                            tooltip: primaryLabel,
                            style: IconButton.styleFrom(
                              fixedSize: Size.square(
                                compact ? 48 : RecordingTokens.primarySize,
                              ),
                              padding: compact
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.all(8),
                              backgroundColor: compact
                                  ? Colors.transparent
                                  : const Color(0x38FFFFFF),
                              disabledBackgroundColor: compact
                                  ? Colors.transparent
                                  : const Color(0x38FFFFFF),
                              shape: const CircleBorder(),
                            ),
                            onPressed:
                                pending ||
                                    state.busy ||
                                    (state.saving &&
                                        !allowPlaybackWhileSaving) ||
                                    (!loadOnAction &&
                                        phase == RecordingAudioPhase.idle)
                                ? null
                                : onPrimary,
                            icon: compact
                                ? SizedBox.square(
                                    dimension: 40,
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        color: Color(0x38FFFFFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: _primaryGlyph(
                                          phase,
                                          pending,
                                          compact,
                                        ),
                                      ),
                                    ),
                                  )
                                : _primaryGlyph(phase, pending, compact),
                          ),
                        ),
                      ],
                    ),
                    if (!inline)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: double.infinity,
                          child: NativeRecordingWaveform(
                            levels: waveform,
                            playing: phase == RecordingAudioPhase.playing,
                            paused: phase == RecordingAudioPhase.paused,
                            height: compact ? 30 : 38,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (state.message.isNotEmpty &&
              !(compact && state.message == '音频加载失败'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  state.message,
                  key: const ValueKey('recording-message'),
                  style: RecordingTokens.notice,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _action(IconButton button) => Semantics(
    container: true,
    button: true,
    enabled: button.onPressed != null,
    label: button.tooltip!,
    onTap: button.onPressed,
    excludeSemantics: true,
    child: button,
  );

  Widget _primaryGlyph(RecordingAudioPhase phase, bool pending, bool compact) =>
      pending || state.busy
      ? _spinner(compact ? 19 : 24)
      : Icon(
          compact
              ? Icons.refresh_rounded
              : phase == RecordingAudioPhase.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: compact
              ? 21
              : phase == RecordingAudioPhase.playing
              ? 30
              : 34,
        );

  Widget _saveGlyph(bool compact, bool loading) {
    final size = loading ? (compact ? 15.0 : 19.0) : (compact ? 21.0 : 27.0);
    final glyph = SvgPicture.asset(
      'assets/images/translation/translation_0.svg',
      width: size,
      height: size,
    );
    if (!loading) return glyph;
    return SizedBox.square(
      dimension: compact ? 27 : 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0x8CFFFFFF),
            ),
          ),
          glyph,
        ],
      ),
    );
  }

  Widget _spinner(double size) => SizedBox.square(
    dimension: size,
    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}
