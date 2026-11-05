import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_admission.dart';
import '../domain/call_launch_request.dart';

class ApiCallAdmissionNoticeRepository
    implements CallAdmissionNoticeRepository {
  const ApiCallAdmissionNoticeRepository(this._api);
  final AccountApi _api;

  @override
  Future<CallAdmissionNoticeReceipt> commit(CallLaunchRequest request) async {
    if (!request.isValid ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(request.sessionId)) {
      throw CallAdmissionNoticeFailure.terminal;
    }
    try {
      final data = AccountApi.object(
        await _api.request(
          'api/agent/conversations/${request.sessionId}/task-call-points-notices',
          method: 'POST',
          body: {
            'confirmationKey': sha256
                .convert(utf8.encode(request.stableAlias))
                .toString(),
            'recipientCount': request.confirmation.recipientCount,
          },
          exposedStatuses: const {400, 403, 404, 409, 422},
        ),
      );
      final eventId = data['eventId'], sequence = data['sequence'];
      if (data['sessionId'] != request.sessionId ||
          eventId is! String ||
          eventId.trim().isEmpty ||
          sequence is! int ||
          sequence < 1 ||
          data['created'] is! bool) {
        throw CallAdmissionNoticeFailure.terminal;
      }
      return CallAdmissionNoticeReceipt(
        sessionId: request.sessionId,
        eventId: eventId,
        sequence: sequence,
        created: data['created'] as bool,
      );
    } on ApiFailure catch (error) {
      throw switch (error) {
        ApiFailure.network ||
        ApiFailure.rejected => CallAdmissionNoticeFailure.retryable,
        _ => CallAdmissionNoticeFailure.terminal,
      };
    } on ApiHttpFailure {
      throw CallAdmissionNoticeFailure.terminal;
    }
  }
}
