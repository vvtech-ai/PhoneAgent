import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_session.dart';
import '../domain/batch_call_session_repository.dart';
import 'api_batch_call_session_repository.dart';

class ApiCallSessionRepository
    implements CallSessionRepository, BatchCallSessionRepositoryFactory {
  ApiCallSessionRepository(this._api, this._accountId);
  final AccountApi _api;
  final String _accountId;
  static const _base = 'api/assistant/realtime/call';

  @override
  CallSessionRepository forBatch(
    String sessionId,
    String batchId,
    String attemptId,
  ) => ApiBatchCallSessionRepository(
    _api,
    _accountId,
    sessionId,
    batchId,
    attemptId,
    this,
  );

  static CallSessionSnapshot decodeSnapshot(
    Object? value,
    CallSessionTarget target,
  ) => _snapshot(value, target);

  Map<String, Object?> _body(CallSessionTarget target) {
    if (_accountId.trim().isEmpty || !target.isValid) {
      throw ApiFailure.invalidResponse;
    }
    return {
      'userId': _accountId,
      if (target.taskId.isNotEmpty) 'taskId': target.taskId,
      if (target.callId.isNotEmpty) 'callId': target.callId,
    };
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async =>
      _snapshot(
        await _api.request(
          '$_base/session/status',
          method: 'POST',
          body: _body(target),
        ),
        target,
      );

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async =>
      _snapshot(
        await _api.request(
          '$_base/hangup',
          method: 'POST',
          body: {..._body(target), 'reason': '用户在 App 端挂断通话'},
        ),
        target,
      );

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) async {
    if (target.callId.isEmpty) throw ApiFailure.invalidResponse;
    final data = AccountApi.object(
      await _api.request(
        'api/agent-calls/monitor/token',
        method: 'POST',
        body: _body(target),
      ),
    );
    final ticket = _text(data, 'ticket');
    final expires = DateTime.tryParse(_text(data, 'expiresAt'));
    int positive(String key, int fallback) {
      final value = data[key] ?? fallback;
      if (value is! int || value <= 0) throw ApiFailure.invalidResponse;
      return value;
    }

    final encoding = data['encoding'] == null
        ? 'PCM_S16LE'
        : _text(data, 'encoding');
    if (ticket.isEmpty || expires == null || encoding.isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    return CallMonitorTicket(
      ticket: ticket,
      expiresAt: expires,
      sampleRate: positive('sampleRate', 16000),
      channels: positive('channels', 1),
      encoding: encoding,
    );
  }

  static CallSessionSnapshot _snapshot(
    Object? value,
    CallSessionTarget target,
  ) {
    final data = AccountApi.object(value);
    bool flag(String key) {
      final value = data[key];
      if (value is! bool) throw ApiFailure.invalidResponse;
      return value;
    }

    final snapshot = CallSessionSnapshot(
      callId: _text(data, 'callId'),
      taskId: _text(data, 'taskId'),
      callState: _text(data, 'callState'),
      handoffMode: _text(data, 'handoffMode'),
      sceneType: _text(data, 'sceneType'),
      targetName: _text(data, 'targetName'),
      phoneNumber: _text(data, 'dialNumber').isNotEmpty
          ? _text(data, 'dialNumber')
          : _text(data, 'phoneNumber'),
      backendCallEnabled: flag('backendCallEnabled'),
      handoffSupported: flag('handoffSupported'),
      appRtcRequired: flag('appRtcRequired'),
      dialogueDetail: _text(data, 'dialogueDetail'),
      statusMessage: _text(data, 'statusMessage'),
      resultCode: _text(data, 'resultCode'),
      resultReason: _text(data, 'resultReason'),
      resultText: _text(data, 'resultText'),
      updatedAt: _text(data, 'updatedAt'),
      launchReady: data['launchReady'] == true,
      dialFailureObserved: data['dialFailureObserved'] == true,
      primaryClosed: data['primaryClosed'] == true,
    );
    if (!snapshot.belongsTo(target)) throw ApiFailure.invalidResponse;
    return snapshot;
  }

  static String _text(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is! String) throw ApiFailure.invalidResponse;
    return value.trim();
  }
}
