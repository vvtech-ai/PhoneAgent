import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/recovery/task_error_status_command.dart';

class ApiTaskErrorStatusGateway implements TaskErrorStatusGateway {
  ApiTaskErrorStatusGateway(this._api, this.accountId);
  final AccountApi _api;
  final String accountId;

  @override
  Future<String> send(TaskErrorStatusCommand command) async {
    final data = AccountApi.object(
      await _api.request(
        'api/agent/conversations/${command.sessionId}/interrupt',
        method: 'POST',
        body: {
          'userId': accountId,
          'reason': command.reason.wire,
          'commandId': command.commandId,
          'idempotencyKey': command.commandId,
          'traceId': command.commandId,
        },
      ),
    );
    final status = data['status'];
    if (data['sessionId'] != command.sessionId ||
        status is! String ||
        !RegExp(r'^[A-Z_]{1,64}$').hasMatch(status)) {
      throw ApiFailure.invalidResponse;
    }
    return status;
  }
}
