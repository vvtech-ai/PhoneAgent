import 'package:flutter/material.dart';
import '../../../../core/design/ai_content_notice.dart';

import '../../domain/translation_call_view.dart';
import 'translation_dtmf_pad.dart';

const _labelStyle = TextStyle(color: Color(0xFFDCE3F0), fontSize: 13);
const _labelGap = 7.0;

class TranslationCallControls extends StatelessWidget {
  const TranslationCallControls({
    super.key,
    required this.state,
    required this.onMute,
    required this.onSpeaker,
    required this.onPad,
    required this.onDigit,
    required this.onHangup,
    this.includeAiNotice = true,
  });
  final bool includeAiNotice;
  final TranslationCallView state;

  TranslationCallControls get actionsOnly => TranslationCallControls(
    key: key,
    state: state,
    onMute: onMute,
    onSpeaker: onSpeaker,
    onPad: onPad,
    onDigit: onDigit,
    onHangup: onHangup,
    includeAiNotice: false,
  );
  final VoidCallback onMute, onSpeaker, onPad, onHangup;
  final ValueChanged<String> onDigit;
  @override
  Widget build(BuildContext context) {
    final pad = state.dialPad
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TranslationDtmfPad(
                enabled:
                    !state.terminal && !state.stopping && !state.controlsBusy,
                onDigit: onDigit,
                enhanced:
                    state.dtmfFeedbackAvailable &&
                    state.enhancedDtmfFeedback &&
                    Theme.of(context).platform == TargetPlatform.android,
              ),
              const SizedBox(height: 12),
            ],
          )
        : const SizedBox(width: double.infinity);
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        Theme.of(context).platform == TargetPlatform.iOS;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (animate)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: pad,
          )
        else
          pad,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Control(
              '静音',
              state.muted ? Icons.mic_off : Icons.mic,
              state.muted,
              state.terminal || state.stopping || state.controlsBusy
                  ? null
                  : onMute,
            ),
            _Control(
              '拨号盘',
              Icons.dialpad,
              state.dialPad,
              state.terminal || state.stopping || state.controlsBusy
                  ? null
                  : onPad,
            ),
            _Control(
              '扬声器',
              state.speaker ? Icons.volume_up : Icons.volume_off,
              state.speaker,
              state.terminal || state.stopping || state.controlsBusy
                  ? null
                  : onSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Control(
          '挂断',
          Icons.call_end,
          true,
          state.terminal || state.stopping ? null : onHangup,
          danger: true,
        ),
        if (includeAiNotice) ...[
          SizedBox(
            height: _labelGap + AiContentNotice.iosSafeAreaAdjustment(context),
          ),
          const AiContentNotice.dark(),
        ],
      ],
    );
  }
}

/// v65 TranslationCallScreen uses these platform vector icons and 64dp controls.
class _Control extends StatelessWidget {
  const _Control(
    this.label,
    this.icon,
    this.active,
    this.onTap, {
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final bool active, danger;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        key: ValueKey('translation-control-$label'),
        toggled: danger ? null : active,
        button: true,
        enabled: onTap != null,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: 64,
            child: Material(
              color: danger
                  ? const Color(0xFFFF3B35)
                  : active
                  ? const Color(0xFF506489)
                  : const Color(0xFF31476F),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: _labelGap),
      ExcludeSemantics(child: Text(label, style: _labelStyle)),
    ],
  );
}
