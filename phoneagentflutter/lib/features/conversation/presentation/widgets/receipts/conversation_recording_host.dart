import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/call_recording_providers.dart';
import '../../../../../app/recording_providers.dart';
import '../../../../calls/presentation/controller/conversation_call_controller.dart';
import '../../controller/conversation_recordings_controller.dart';
import 'call_recording_route.dart';

typedef RecordingControlBuilder = Widget Function(String callId, bool compact);

class ConversationRecordingHost extends ConsumerStatefulWidget {
  const ConversationRecordingHost({
    super.key,
    required this.builder,
    required this.voiceMode,
    this.calls,
  });
  final Widget Function(RecordingControlBuilder) builder;
  final bool voiceMode;
  final ConversationCallController? calls;
  @override
  ConsumerState<ConversationRecordingHost> createState() =>
      _ConversationRecordingHostState();
}

class _ConversationRecordingHostState
    extends ConsumerState<ConversationRecordingHost>
    with WidgetsBindingObserver {
  ConversationRecordingsController? _manager;
  VoidCallback? _callsListener;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenCalls();
  }

  void _listenCalls() {
    _callsListener = widget.calls?.addListener((_) {
      _manager?.setVisible(widget.calls?.snapshot.showCall != true);
    }, fireImmediately: false);
  }

  @override
  void didUpdateWidget(covariant ConversationRecordingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.voiceMode && widget.voiceMode) _manager?.stopPlayback();
    if (oldWidget.calls != widget.calls) {
      _callsListener?.call();
      _listenCalls();
      _manager?.setVisible(widget.calls?.snapshot.showCall != true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _manager?.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callsListener?.call();
    _manager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(recordingSupportedProvider)) {
      return widget.builder(
        (_, compact) => Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            compact
                ? '录音请在 App 播放'
                : '请在 Android 或 iOS App 中播放和保存录音；Web 可使用隔离演练。',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    final manager = ref.watch(conversationRecordingsProvider(this));
    if (!identical(_manager, manager)) {
      _manager = manager;
      manager.setForeground(
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      manager.setVisible(widget.calls?.snapshot.showCall != true);
    }
    return widget.builder(
      (callId, compact) => CallRecordingRoute(
        key: ValueKey('call-recording:$callId'),
        manager: manager,
        callId: callId,
        compact: compact,
      ),
    );
  }
}
