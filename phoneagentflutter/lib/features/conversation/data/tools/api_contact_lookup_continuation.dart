import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/tools/phone_contact_lookup.dart';

class ApiContactLookupContinuation
    implements
        ContactLookupContinuation,
        CommandAwareContactLookupContinuation {
  ApiContactLookupContinuation(this._api, this._accountId);
  final AccountApi _api;
  final String _accountId;

  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async {
    return _submit(
      sessionId: sessionId,
      toolCallId: toolCallId,
      result: result,
    );
  }

  @override
  Future<AgentEvent> submitWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required Map<String, Object?> result,
  }) => _submit(
    sessionId: sessionId,
    toolCallId: toolCallId,
    commandId: commandId,
    result: result,
  );

  Future<AgentEvent> _submit({
    required String sessionId,
    required String toolCallId,
    String? commandId,
    required Map<String, Object?> result,
  }) async {
    if ([sessionId, toolCallId, _accountId].any((s) => s.trim().isEmpty) ||
        commandId != null && commandId.trim().isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    final data = AccountApi.object(
      await _api.request(
        'api/assistant/agent/contact-lookup-result',
        method: 'POST',
        body: {
          'sessionId': sessionId,
          'pendingToolCallId': toolCallId,
          'userId': _accountId,
          'result': result,
          if (commandId != null) 'commandId': commandId,
        },
      ),
    );
    return decode(data, sessionId);
  }

  static AgentEvent decode(Object? response, String sessionId) {
    final data = AccountApi.object(response);
    if (data['sessionId'] != sessionId ||
        data['type'] is! String ||
        (data['type'] as String).trim().isEmpty ||
        data['text'] != null && data['text'] is! String) {
      throw ApiFailure.invalidResponse;
    }
    final type = data['type'] as String;
    return AgentEvent(
      switch (type) {
        'TEXT_REPLY' ||
        'CALL_RESULT' ||
        'BATCH_CALL_RESULT' => AgentEventKind.finalResponse,
        'ERROR' => AgentEventKind.error,
        _ => AgentEventKind.signal,
      },
      sessionId: sessionId,
      text: data['text'] as String? ?? '',
      payload: Map.unmodifiable(data),
    );
  }
}
