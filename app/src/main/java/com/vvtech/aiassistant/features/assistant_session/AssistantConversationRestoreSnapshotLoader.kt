package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.flow.MutableStateFlow

internal class AssistantConversationRestoreSnapshotLoader(
    private val restoreUseCase: AssistantConversationRestoreUseCase,
    private val conversationList: MutableStateFlow<List<ConversationListItem>>
) {
    suspend fun load(sessionId: String): AssistantConversationRestoreSnapshot {
        return restoreUseCase.loadSnapshot(sessionId, ::rawStatusFor)
    }

    private fun rawStatusFor(sessionId: String): String {
        return conversationList.value.firstOrNull { it.sessionId == sessionId }?.status.orEmpty()
    }
}
