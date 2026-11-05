import 'conversation_messages.dart';
import 'artifacts/task_artifact.dart';
import 'conversation_option_presentation.dart';

/// Shared live/history display policy. Source facts and tool execution stay intact.
abstract final class ConversationMessagePresentation {
  static bool isPlain(ConversationMessage message) =>
      message.thinking == null &&
      message.toolCard == null &&
      message.confirmation == null &&
      message.batchConfirmation == null &&
      message.receipt == null &&
      message.batchReceipt == null &&
      message.artifact == null &&
      message.document == null &&
      message.questions == null &&
      message.questionSourceText == null &&
      message.options.isEmpty;

  static List<ConversationMessage> project(
    Iterable<ConversationMessage> messages,
  ) {
    final visible = <ConversationMessage>[];
    final owners = <Object, int>{};
    var turnStart = 0;
    for (var message in messages) {
      if (message.role == MessageRole.user) turnStart = visible.length + 1;
      if (message.confirmation != null) {
        final prior = _confirmationOwner(visible, turnStart, message);
        if (prior >= 0 &&
            (prior < turnStart || !_sameTool(visible[prior], message))) {
          if (message.text.trim().isEmpty ||
              message.text.trim() == visible[prior].text.trim()) {
            continue;
          }
          message = message.copyWith(
            id: '${message.id}:narrative',
            clearConfirmation: true,
          );
        }
      }
      final key = _identity(message);
      final candidateOwner = ConversationOptionPresentation.ownerIndex(
        visible,
        turnStart,
        message,
      );
      if (candidateOwner >= 0) {
        visible[candidateOwner] = ConversationOptionPresentation.merge(
          visible[candidateOwner],
          message,
        );
        owners[key] = candidateOwner;
        continue;
      }
      final owner = owners[key];
      if (owner == null) {
        owners[key] = visible.length;
        visible.add(message);
      } else {
        visible[owner] = message;
      }
    }
    return List.unmodifiable(
      visible.where((message) {
        final card = message.toolCard;
        if (card != null) {
          final name = card.toolName.toLowerCase().replaceAll(
            RegExp('[^a-z0-9]'),
            '',
          );
          if (visible.any(
            (owner) =>
                ((name == 'provideskilltemplate' &&
                    _sameCommand(owner, message) &&
                    owner.artifact?.kind == TaskArtifactKind.template) ||
                (name == 'makecall' &&
                    (owner.confirmation != null || owner.receipt != null) &&
                    _sameTool(owner, message)) ||
                (_sameCommand(owner, message) &&
                    _sameTool(owner, message) &&
                    ((name == 'showoptions' && owner.options.isNotEmpty) ||
                        (name == 'askuser' &&
                            (owner.questions != null ||
                                owner.questionSourceText != null))))),
          )) {
            return false;
          }
        }
        if (message.role != MessageRole.assistant ||
            !isPlain(message) ||
            message.text.trim().isEmpty) {
          return true;
        }
        return !visible.any(
          (owner) =>
              owner.role == MessageRole.assistant &&
              !isPlain(owner) &&
              owner.thinking == null &&
              owner.toolCard == null &&
              _sameCommand(owner, message) &&
              owner.text.trim() == message.text.trim() &&
              ((message.toolCallId?.isEmpty ?? true) ||
                  _sameTool(owner, message)),
        );
      }),
    );
  }

  static int _confirmationOwner(
    List<ConversationMessage> visible,
    int turnStart,
    ConversationMessage incoming,
  ) {
    for (var index = visible.length - 1; index >= 0; index--) {
      final prior = visible[index];
      if (prior.confirmation == null) continue;
      if (index < turnStart && !_sameTool(prior, incoming)) continue;
      if (prior.confirmation!.sameIdentityAs(
        incoming.confirmation!,
        toolId: prior.toolCallId,
        otherToolId: incoming.toolCallId,
      )) {
        return index;
      }
    }
    return -1;
  }

  static Object _identity(ConversationMessage message) {
    if (message.artifact case final artifact?) return ('artifact', artifact.id);
    if (message.document case final document?) {
      if (document.batchId.isNotEmpty) return ('document', document.batchId);
    }
    if (message.confirmation != null &&
        (message.toolCallId?.isNotEmpty ?? false)) {
      return ('confirmation', message.toolCallId);
    }
    if (message.batchConfirmation case final confirmation?) {
      return ('batch-confirmation', confirmation.snapshotId);
    }
    final command = message.commandId?.trim() ?? '';
    if (command.isNotEmpty) {
      if (message.toolCard case final card?) {
        return ('tool', command, card.presentationKey);
      }
      if (message.role == MessageRole.assistant &&
          (message.toolCallId?.isNotEmpty ?? false) &&
          message.receipt == null &&
          message.batchReceipt == null &&
          message.thinking == null &&
          !isPlain(message)) {
        return (
          message.options.isNotEmpty ? 'options' : 'prompt',
          command,
          message.toolCallId,
        );
      }
    }
    return ('message', message.id);
  }

  static bool _sameCommand(ConversationMessage a, ConversationMessage b) =>
      (a.commandId?.isNotEmpty ?? false) && a.commandId == b.commandId;
  static bool _sameTool(ConversationMessage a, ConversationMessage b) =>
      (a.toolCallId?.isNotEmpty ?? false) && a.toolCallId == b.toolCallId;
}
