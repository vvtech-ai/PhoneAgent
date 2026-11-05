import '../../../../../core/design/native_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import '../../controller/preview_call_recording_session.dart';
import '../../controller/conversation_recordings_controller.dart';
import '../../../domain/recording_playback_arbiter.dart';
import '../../../../translation_history/data/preview_recording_audio.dart';
import 'call_recording_route.dart';

/// Explicit preview composition only. Never registered in production providers.
class PreviewCallRecording extends StatefulWidget {
  const PreviewCallRecording({
    super.key,
    required this.compact,
    this.scenario = RecordingPreviewScenario.normal,
    this.arbiter,
    this.manager,
    this.callId = 'preview-recording',
  });
  final bool compact;
  final RecordingPreviewScenario scenario;
  final RecordingPlaybackArbiter? arbiter;
  final ConversationRecordingsController? manager;
  final String callId;
  @override
  State<PreviewCallRecording> createState() => _PreviewCallRecordingState();
}

class _PreviewCallRecordingState extends State<PreviewCallRecording> {
  late final ConversationRecordingsController _manager;
  @override
  void initState() {
    super.initState();
    _manager =
        widget.manager ??
        createPreviewCallRecordings(
          _choose,
          arbiter: widget.arbiter,
          scenario: widget.scenario,
        );
  }

  Future<bool> _choose() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => NativeConfirmationDialog(
          title: 'MOCK · 保存本次录音',
          message: '模拟选择保存位置，不写真实文件。',
          dismissLabel: '取消保存',
          confirmLabel: '模拟保存',
        ),
      ) ??
      false;

  @override
  void dispose() {
    if (widget.manager == null) _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallRecordingRoute(
    manager: _manager,
    callId: widget.callId,
    compact: widget.compact,
  );
}
