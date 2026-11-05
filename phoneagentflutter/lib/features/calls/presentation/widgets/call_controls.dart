import 'package:flutter/material.dart';
import '../../../../core/design/ai_content_notice.dart';
import '../controller/call_presentation.dart';
import '../controller/call_session_state.dart';
import 'call_icons.dart';
import 'native_call_audio_source_sheet.dart';

const _labelGap = 8.0;
const _labelStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.bold,
);

class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.call,
    required this.monitor,
    required this.onMonitor,
    required this.onHangup,
    required this.onSource,
  });
  final CallSessionState call;
  final CallMonitorView monitor;
  final VoidCallback onMonitor, onHangup, onSource;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _button(
            '监听',
            monitor.playing ? '停止监听' : '开始监听',
            CallIcons.icon(CallIcons.listen, off: monitor.playing),
            CallPresentation.active(call) && !monitor.busy ? onMonitor : null,
          ),
          _button(
            call.hangingUp ? '挂断中' : '挂断',
            '挂断',
            CallIcons.icon(CallIcons.hangup),
            call.canHangUp ? onHangup : null,
            danger: true,
          ),
          _button(
            monitor.source.label,
            '音源，${monitor.source.label}',
            CallIcons.icon(CallIcons.source(monitor.source)),
            CallPresentation.active(call) && !monitor.controlsBusy
                ? onSource
                : null,
          ),
        ],
      ),
      const SizedBox(height: _labelGap),
      Opacity(
        opacity: call.canHangUp ? 1 : .38,
        child: AiContentNotice(
          style: _labelStyle.copyWith(
            fontSize: (_labelStyle.fontSize! * .7).roundToDouble(),
          ),
        ),
      ),
    ],
  );
  Widget _button(
    String label,
    String semantic,
    Widget icon,
    VoidCallback? onTap, {
    bool danger = false,
  }) => Opacity(
    opacity: onTap == null ? .38 : 1,
    child: SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: semantic,
            button: true,
            enabled: onTap != null,
            onTap: onTap,
            child: ExcludeSemantics(
              child: Material(
                color: danger
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF252A34),
                shape: const CircleBorder(),
                child: InkWell(
                  key: ValueKey('call-$semantic'),
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 52,
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _labelGap),
          Text(label, maxLines: 1, style: _labelStyle),
        ],
      ),
    ),
  );
}

Future<CallAudioSource?> showCallAudioSources(
  BuildContext context,
  CallMonitorView monitor, {
  bool preview = false,
}) => showModalBottomSheet<CallAudioSource>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF191D25),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  barrierColor: const Color(0x99000000),
  enableDrag: false,
  builder: (context) => NativeCallAudioSourceSheet(
    monitor: monitor,
    preview: preview,
    onSelect: (source) => Navigator.pop(context, source),
    onCancel: () => Navigator.pop(context),
  ),
);
