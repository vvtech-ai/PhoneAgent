import 'package:flutter/material.dart';
import '../../../../../core/design/native_notice.dart';
import '../../controller/conversation_recordings_controller.dart';
import '../../controller/call_recording_save_controller.dart';
import '../../../../translation_history/presentation/controller/recording_audio_controller.dart';
import 'call_recording_control.dart';

class CallRecordingRoute extends StatefulWidget {
  const CallRecordingRoute({
    super.key,
    required this.manager,
    required this.callId,
    required this.compact,
  });
  final ConversationRecordingsController manager;
  final String callId;
  final bool compact;
  @override
  State<CallRecordingRoute> createState() => _CallRecordingRouteState();
}

class _CallRecordingRouteState extends State<CallRecordingRoute> {
  late ConversationRecordingEntry _entry;
  late VoidCallback _audioListener, _saveListener;
  RecordingAudioState _audio = const RecordingAudioState();
  CallRecordingSaveState _save = const CallRecordingSaveState();
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _entry = widget.manager.attach(widget.callId);
    final entry = _entry;
    _save = const CallRecordingSaveState();
    _audioListener = _entry.audio.addListener((value) {
      if (mounted) setState(() => _audio = value);
    });
    _saveListener = _entry.save.addListener((value) {
      if (!mounted) return;
      final completed = _save.saving && !value.saving;
      setState(() => _save = value);
      if (completed && value.message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(entry, _entry) &&
              TickerMode.of(context) &&
              ModalRoute.of(context)?.isCurrent == true) {
            showNativeNotice(context, value.message);
          }
        });
      }
    });
  }

  void _detach(ConversationRecordingsController manager, String id) {
    _audioListener();
    _saveListener();
    manager.detach(id, _entry);
  }

  @override
  void didUpdateWidget(covariant CallRecordingRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager ||
        oldWidget.callId != widget.callId) {
      _detach(oldWidget.manager, oldWidget.callId);
      _attach();
    }
  }

  @override
  void dispose() {
    _detach(widget.manager, widget.callId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallRecordingControl(
    key: ValueKey((widget.manager, widget.callId)),
    state: _audio,
    compact: widget.compact,
    saving: _save.saving,
    onPrimary: _entry.playback.primary,
    onSave: _entry.save.save,
  );
}
