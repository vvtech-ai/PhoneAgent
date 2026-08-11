package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem

internal enum class AssistantSessionResumeRole {
    Assistant,
    User,
}

/**
 * UI compatibility model for applying an already-projected restore snapshot.
 * Durable history is supplied by the timeline repository, never reconstructed here.
 */
internal data class AssistantSessionResumeStep(
    val role: AssistantSessionResumeRole,
    val text: String,
    val status: String = "",
    val callResult: CallResultPayload? = null,
    val batchCallResult: BatchCallResultPayload? = null,
)

internal data class AssistantSessionTimelineRestoreSnapshot(
    val timelineItems: List<ConversationTimelineItem>,
)
