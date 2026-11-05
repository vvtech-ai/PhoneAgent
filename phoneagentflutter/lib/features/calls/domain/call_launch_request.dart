import '../../conversation/domain/call_confirmation.dart';
import '../../conversation/domain/agent_protocol.dart';
import 'dart:convert';

/// A live request, not a history replay or permission inferred from a UI card.
class CallLaunchRequest {
  CallLaunchRequest({
    required this.sessionId,
    required this.toolId,
    required this.commandId,
    required this.ordinal,
    required Map<String, Object?> spec,
  }) : confirmation = CallConfirmation.fromPayload(spec),
       specSignature = jsonEncode(spec),
       scene = _text(spec['scene']),
       _summary = spec['summaryLines'] is List
           ? (spec['summaryLines'] as List).whereType<String>().join('\u001e')
           : '',
       explicitCount = spec['recipientCount'] is int
           ? spec['recipientCount'] as int
           : null;
  final String sessionId, toolId, commandId, scene;
  final int ordinal;
  final int? explicitCount;
  final CallConfirmation confirmation;
  final String specSignature;
  final String _summary;
  String get identity => '$sessionId:$toolId';
  bool matchesConfirmation(
    String? displayedToolId,
    CallConfirmation? displayed,
  ) =>
      displayedToolId == toolId &&
      displayed != null &&
      confirmation.sameSpecAs(displayed);
  bool get isValid =>
      sessionId.trim().isNotEmpty &&
      toolId.trim().isNotEmpty &&
      commandId.trim().isNotEmpty &&
      ordinal > 0 &&
      confirmation.hasContent;

  String get stableAlias => [
    'task-confirmation-v1',
    '$ordinal',
    scene,
    confirmation.targetName,
    confirmation.phoneNumber,
    confirmation.primaryGoal,
    explicitCount?.toString() ?? '',
    _summary,
  ].map((s) => s.trim()).join('\u0000');
  List<String> get aliases => [toolId.trim(), stableAlias];

  AgentCommand command(
    String accountId,
    String id,
    String traceId, {
    String confirmationText = '',
  }) => AgentCommand(
    sessionId: sessionId,
    userId: accountId,
    commandId: id,
    idempotencyKey: id,
    traceId: traceId,
    actionId: 'confirm_call',
    pendingToolCallId: toolId,
    actionPayload: confirmationText.isEmpty
        ? null
        : {'confirmationText': confirmationText},
  );

  bool sameTask(CallLaunchRequest other) {
    String normalized(String value) =>
        value.trim().toLowerCase().replaceAll(' ', '');
    final phone = normalized(confirmation.phoneNumber);
    final peerPhone = normalized(other.confirmation.phoneNumber);
    return sessionId == other.sessionId &&
        confirmation.recipientCount == other.confirmation.recipientCount &&
        normalized(scene) == normalized(other.scene) &&
        normalized(confirmation.targetName) ==
            normalized(other.confirmation.targetName) &&
        normalized(confirmation.primaryGoal) ==
            normalized(other.confirmation.primaryGoal) &&
        (phone.isEmpty || peerPhone.isEmpty || phone == peerPhone);
  }

  static String _text(Object? value) => value is String ? value.trim() : '';
  @override
  String toString() => 'CallLaunchRequest(redacted)';
}
