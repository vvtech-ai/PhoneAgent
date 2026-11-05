import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/history/ledger_sync.dart';

class ApiConversationHistoryRepository
    implements ConversationHistoryRepository {
  ApiConversationHistoryRepository(this._api, this._ledger, this.accountId);
  final AccountApi _api;
  final LedgerSync _ledger;
  final String accountId;
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sessionId)) {
      throw ApiFailure.invalidResponse;
    }
    final dto = AccountApi.object(
      await _api.request('api/agent/conversations/$sessionId'),
    );
    if (dto['sessionId'] != sessionId) throw ApiFailure.invalidResponse;
    String field(String key) {
      final v = dto[key];
      if (v != null && v is! String) throw ApiFailure.invalidResponse;
      return v as String? ?? '';
    }

    final detail = ConversationDetail(
      sessionId: sessionId,
      title: field('title'),
      status: field('status'),
      sceneType: field('sceneType'),
      createdAt: field('createdAt'),
      updatedAt: field('updatedAt'),
      activeBatchId: field('activeBatchId'),
      activeCommandId: field('activeCommandId'),
      pinnedSkillId: field('pinnedSkillId'),
      taskCallModelId: field('taskCallModelId'),
    );
    try {
      return RestoredConversation(
        detail,
        ledger: await _ledger.sync(accountId, sessionId),
      );
    } on TimelineFailure catch (error) {
      if (error != TimelineFailure.legacyNoLedger) {
        rethrow;
      }
      // messagesJson intentionally ignored: v65 does not guess old runtime JSON.
      return RestoredConversation(detail, compatibilityReason: error);
    }
  }
}
