import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/confirmation/confirmation_supplement.dart';

class ApiConfirmationSupplementRepository
    implements ConfirmationSupplementRepository {
  const ApiConfirmationSupplementRepository(this.api);
  final AccountApi api;
  @override
  Future<String> save(String sessionId, ConfirmationSupplement record) async {
    final value = await api.request(
      'api/agent/conversations/$sessionId/call-confirmation-supplements',
      method: 'POST',
      body: {
        'recordId': record.id,
        'pendingToolCallId': record.toolId,
        'userText': record.userText,
        'assistantText': record.assistantText,
      },
    );
    if (value is! Map ||
        value['recordId'] != record.id ||
        value['eventId'] is! String ||
        (value['eventId'] as String).isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    return value['eventId'] as String;
  }
}
