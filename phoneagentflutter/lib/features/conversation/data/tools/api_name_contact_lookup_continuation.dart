import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/tools/name_contact_lookup.dart';
import 'api_contact_lookup_continuation.dart';

class ApiNameContactLookupContinuation
    implements
        NameContactLookupContinuation,
        CommandAwareNameContactLookupContinuation {
  ApiNameContactLookupContinuation(this._api, this._accountId);
  final AccountApi _api;
  final String _accountId;

  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) async {
    return _submitNames(
      sessionId: sessionId,
      toolCallId: toolCallId,
      results: results,
    );
  }

  @override
  Future<AgentEvent> submitNamesWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required List<Map<String, Object?>> results,
  }) => _submitNames(
    sessionId: sessionId,
    toolCallId: toolCallId,
    commandId: commandId,
    results: results,
  );

  Future<AgentEvent> _submitNames({
    required String sessionId,
    required String toolCallId,
    String? commandId,
    required List<Map<String, Object?>> results,
  }) async {
    if ([sessionId, toolCallId, _accountId].any((v) => v.trim().isEmpty) ||
        commandId != null && commandId.trim().isEmpty ||
        results.isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    final response = await _api.request(
      'api/assistant/agent/device-contacts-lookup-result',
      method: 'POST',
      body: {
        'sessionId': sessionId,
        'pendingToolCallId': toolCallId,
        'userId': _accountId,
        'results': results,
        'channel': 'voice',
        if (commandId != null) 'commandId': commandId,
      },
    );
    return ApiContactLookupContinuation.decode(response, sessionId);
  }
}
