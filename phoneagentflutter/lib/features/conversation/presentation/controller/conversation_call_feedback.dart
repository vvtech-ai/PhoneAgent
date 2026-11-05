import '../../../calls/domain/call_launch_coordinator.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';
import '../../domain/conversation_messages.dart';
import 'conversation_message_store.dart';
import 'conversation_state.dart';

/// Projects the existing preparation lifecycle without owning its timer or IO.
class ConversationCallFeedback {
  ConversationCallFeedback({
    required this.current,
    required this.read,
    required this.write,
    required this.nextId,
    required this.messages,
    required this.publish,
  });
  final bool Function() current;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final String Function() nextId;
  final ConversationMessageStore messages;
  final void Function() publish;
  CallLaunchPhase? _previous;
  String? _command;

  void accept(ConversationCallState state, String confirmationText) {
    if (!current()) return;
    final phase = state.launch.phase;
    final entering = phase != _previous;
    _previous = phase;
    if (phase == CallLaunchPhase.waiting && entering) {
      _command = nextId();
      messages.upsert(
        ConversationMessage(
          id: 'local:$_command:user',
          role: MessageRole.user,
          text: confirmationText.trim(),
          commandId: _command!,
          transient: true,
        ),
      );
      write(read().copy(preparingCall: true, activity: '正在准备拨打…'));
      publish();
    } else if (phase != CallLaunchPhase.waiting &&
        phase != CallLaunchPhase.checking) {
      if (read().preparingCall) {
        write(read().copy(preparingCall: false, activity: ''));
      }
      if (phase != CallLaunchPhase.submitting) _command = null;
    }
  }

  String takeCommand() {
    final id = _command ?? nextId();
    _command = null;
    return id;
  }
}
