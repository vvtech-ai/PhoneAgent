package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.FinalTaskDisplayItem
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.finalTaskDisplaySortEpochMillis
import com.vvtech.aiassistant.features.assistant.toCompletedTaskRecord
import com.vvtech.aiassistant.features.assistant.toFinalTaskDisplayItem
import com.vvtech.aiassistant.model.ConversationListItem

internal data class TaskPageRow(
    val key: String,
    val item: FinalTaskDisplayItem,
    val conversationSessionId: String?,
    val originalIndex: Int
)

internal data class TaskPageRows(
    val rows: List<TaskPageRow>,
    val activeConversationCount: Int,
    val completedConversationCount: Int
)

internal fun buildTaskPageRows(
    records: List<FinalTaskRecord>,
    conversations: List<ConversationListItem>
): TaskPageRows {
    val completedConversations = conversations.filter { isCompletedConversationStatus(it.status) }
    val activeConversations = conversations.filterNot { isCompletedConversationStatus(it.status) }
    val rows = buildList {
        activeConversations.forEachIndexed { index, conversation ->
            val item = conversation.toFinalTaskDisplayItem(index).withSkillScene(conversation.activeSkillId)
            add(
                TaskPageRow(
                    key = "conversation_${conversation.sessionId}",
                    item = item,
                    conversationSessionId = conversation.sessionId,
                    originalIndex = index
                )
            )
        }
        completedConversations.forEachIndexed { index, conversation ->
            val item = conversation.toCompletedTaskRecord().toFinalTaskDisplayItem(index)
                .withSkillScene(conversation.activeSkillId)
            add(
                TaskPageRow(
                    key = "conversation_${conversation.sessionId}",
                    item = item,
                    conversationSessionId = conversation.sessionId,
                    originalIndex = activeConversations.size + index
                )
            )
        }
        records.forEachIndexed { index, record ->
            val item = record.toFinalTaskDisplayItem(index)
            add(
                TaskPageRow(
                    key = "record_${item.id}",
                    item = item,
                    conversationSessionId = null,
                    originalIndex = activeConversations.size + completedConversations.size + index
                )
            )
        }
    }.sortedWith(
        compareByDescending<TaskPageRow> { finalTaskDisplaySortEpochMillis(it.item) }
            .thenBy { it.originalIndex }
    )
    return TaskPageRows(
        rows = rows,
        activeConversationCount = activeConversations.size,
        completedConversationCount = completedConversations.size
    )
}

private fun FinalTaskDisplayItem.withSkillScene(activeSkillId: String?): FinalTaskDisplayItem {
    val skillScene = taskDisplaySkillSceneName(activeSkillId) ?: return this
    return copy(sceneName = skillScene)
}
