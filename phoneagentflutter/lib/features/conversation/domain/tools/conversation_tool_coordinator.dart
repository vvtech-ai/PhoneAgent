import '../../../contacts/domain/contact_name_matcher.dart';
import '../agent_protocol.dart';
import '../conversation_messages.dart';
import '../history/conversation_history.dart';
import '../history/ledger_event.dart';
import 'phone_contact_lookup.dart';
import 'name_contact_lookup.dart';
import 'contact_lookup_access_policy.dart';

class ToolContinuation {
  const ToolContinuation(this.event, this.commandId, this.ledger);
  final AgentEvent event;
  final String commandId;
  final LedgerSnapshot? ledger;
}

/// One per conversation. Owns tool side effects, not UI or a second fact store.
class ConversationToolCoordinator {
  ConversationToolCoordinator({required this.history, this.phone, this.names});
  final ConversationHistoryRepository history;
  final PhoneContactLookup? phone;
  final NameContactLookup? names;
  final Set<String> _handled = {};
  bool hasHandled(String toolId) => _handled.contains(toolId);

  bool handles(String type) =>
      type == 'LOOKUP_CONTACT_REQUEST' && phone != null ||
      type == 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST' && names != null;

  Future<ToolContinuation?> run({
    required AgentEvent event,
    required String sessionId,
    required String commandId,
    required ContactInputSource inputSource,
    required bool hasLedger,
    required bool Function() isCurrent,
    void Function(String)? onNotice,
  }) async {
    if (!isCurrent()) return null;
    final type = ConversationMessages.text(event.payload, 'type');
    if (!handles(type)) throw const FormatException('Unsupported tool');
    final tool = ConversationMessages.text(event.payload, 'pendingToolCallId');
    if (tool.trim().isEmpty) throw const FormatException('Missing lookup tool');
    if (!_handled.add(tool)) return null;
    final continuationCommand = '$commandId:contact:$tool';
    final AgentEvent? response;
    if (type == 'LOOKUP_CONTACT_REQUEST') {
      final nested = ConversationMessages.text(
        event.payload,
        'lookupContactPhone',
      );
      response = await phone!.run(
        sessionId: sessionId,
        toolCallId: tool,
        phone: nested.isNotEmpty
            ? nested
            : ConversationMessages.firstText(event.payload, const [
                'phone',
                'phoneNumber',
              ]),
        continuationCommandId: continuationCommand,
        isCurrent: isCurrent,
        onLimitedAccess: () {
          if (isCurrent()) onNotice?.call(ContactLookupAccessPolicy.notice);
        },
      );
    } else {
      final nested = ConversationMessages.object(
        event.payload['lookupDeviceContactsByNames'],
      );
      final raw = nested['names'] ?? event.payload['names'];
      if (raw is! List || raw.any((v) => v is! String)) {
        throw const FormatException('Invalid lookup names');
      }
      response = await names!.run(
        sessionId: sessionId,
        toolCallId: tool,
        names: raw.cast<String>(),
        source: inputSource,
        continuationCommandId: continuationCommand,
        isCurrent: isCurrent,
        onLimitedAccess: () {
          if (isCurrent()) onNotice?.call(ContactLookupAccessPolicy.notice);
        },
      );
    }
    if (!isCurrent() || response == null) return null;
    if (response.sessionId != sessionId) {
      throw const FormatException('Wrong lookup session');
    }
    var command = continuationCommand;
    final responseCommand = ConversationMessages.text(
      response.payload,
      'commandId',
    ).trim();
    if (responseCommand.isNotEmpty) command = responseCommand;
    LedgerSnapshot? ledger;
    if (hasLedger) {
      final restored = await history.restore(sessionId);
      if (!isCurrent()) return null;
      ledger = restored.ledger;
      if (ledger == null || ledger.sessionId != sessionId) {
        throw const FormatException('Missing lookup continuation ledger');
      }
      if (responseCommand.isEmpty &&
          !ledger.events.any((e) => e.commandId == continuationCommand)) {
        command =
            ledger.events
                .where((e) => e.commandId != null)
                .lastOrNull
                ?.commandId ??
            command;
      }
    }
    return ToolContinuation(response, command, ledger);
  }
}
