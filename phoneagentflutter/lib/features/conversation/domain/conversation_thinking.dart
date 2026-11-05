import 'agent_protocol.dart';

/// Native thinking token semantics, independent of transport and task state.
class ConversationThinking {
  const ConversationThinking({this.text = '', this.processing = true});
  final String text;
  final bool processing;

  ConversationThinking accept(AgentEvent event) {
    if (event.kind == AgentEventKind.thinkingDone) return completed();
    if (event.text.isEmpty) return this;
    if (event.payload['append'] == true) {
      final separate =
          (event.payload['start'] == true || !processing) &&
          text.isNotEmpty &&
          !text.endsWith('\n') &&
          !event.text.startsWith('\n');
      return ConversationThinking(
        text: '$text${separate ? '\n' : ''}${event.text}',
      );
    }
    final line = event.text.trim();
    if (line.isEmpty) return this;
    return ConversationThinking(
      text: text.trim().isEmpty ? line : '${text.trim()}\n$line',
    );
  }

  ConversationThinking completed() =>
      ConversationThinking(text: text, processing: false);
}
