package com.vvtech.aiassistant.features.assistant_session

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.features.assistant_tasks.isReadOnlyConversationStatus
import com.vvtech.aiassistant.features.assistant_tasks.normalizeConversationTaskStatus
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot

internal data class AssistantConversationRestoreSnapshot(
    val sessionId: String,
    val title: String,
    val sceneType: String?,
    val resolvedStatus: String,
    val steps: List<AssistantSessionResumeStep>,
    val timeline: AssistantSessionTimelineRestoreSnapshot = AssistantSessionTimelineRestoreSnapshot(emptyList()),
    val readOnly: Boolean,
    val conversationContinuable: Boolean = !readOnly,
    val pendingToolCallId: String?,
    val agentQuestions: com.vvtech.aiassistant.core.model.AskQuestionsPayload?,
    val agentCallSpec: com.vvtech.aiassistant.core.model.CallSpecPayload?,
    val callResult: com.vvtech.aiassistant.core.model.CallResultPayload?,
    val pendingToolRestorable: Boolean = !readOnly,
) {
    val canRestorePending: Boolean
        get() = conversationContinuable && pendingToolRestorable
}

internal fun buildAssistantConversationRestoreSnapshot(
    detail: ConversationDetail,
    rawStatus: String
): AssistantConversationRestoreSnapshot {
    val resolvedStatus = normalizeConversationTaskStatus(
        rawStatus = rawStatus,
        detailStatus = detail.status,
    )
    // Timeline transport failure or a pre-ledger session is an explicit read-only
    // compatibility view. Missing durable facts are never guessed from runtime JSON.
    return AssistantConversationRestoreSnapshot(
        sessionId = detail.sessionId,
        title = detail.title.orEmpty(),
        sceneType = detail.sceneType,
        resolvedStatus = resolvedStatus,
        steps = emptyList(),
        readOnly = true,
        conversationContinuable = false,
        pendingToolCallId = null,
        agentQuestions = null,
        agentCallSpec = null,
        callResult = null,
        pendingToolRestorable = false,
    )
}

internal fun buildAssistantConversationRestoreSnapshot(
    detail: ConversationDetail,
    timeline: ConversationTimelineSnapshot,
): AssistantConversationRestoreSnapshot {
    val resolvedStatus = timeline.projection.conversationStatus.trim().ifBlank { detail.status }
    val readOnly = isReadOnlyConversationStatus(resolvedStatus)
    val canRestorePending = timeline.projection.conversationContinuable &&
        !readOnly &&
        timeline.projection.pendingToolRestorable
    val pending = timeline.events.pendingToolRequest().takeIf { canRestorePending }
    val pendingToolCallId = pending?.payload?.text("toolCallId")?.takeIf(String::isNotBlank)
    val pendingCallSpec = pending?.takeIf { it.payload.text("toolName") == "makeCall" }
        ?.payload?.objectField("arguments")?.toCallSpec()
    return AssistantConversationRestoreSnapshot(
        sessionId = detail.sessionId,
        title = detail.title.orEmpty(),
        sceneType = detail.sceneType,
        resolvedStatus = resolvedStatus,
        steps = emptyList(),
        timeline = AssistantSessionTimelineRestoreSnapshot(timeline.timeline.items),
        readOnly = readOnly,
        conversationContinuable = timeline.projection.conversationContinuable,
        pendingToolCallId = pendingToolCallId,
        agentQuestions = null,
        agentCallSpec = pendingCallSpec,
        callResult = null,
        pendingToolRestorable = canRestorePending,
    )
}

private fun List<ConversationLedgerEvent>.pendingToolRequest(): ConversationLedgerEvent? {
    val resolved = asSequence()
        .filter { it.stableType() == StableConversationLedgerEventType.TOOL_RESULT_RECORDED }
        .map { it.payload.toolIdentity() }
        .toSet()
    return asSequence()
        .filter { it.stableType() == StableConversationLedgerEventType.TOOL_REQUESTED }
        .filterNot { it.payload.toolIdentity() in resolved }
        .maxByOrNull { it.sequence }
}

private fun ConversationLedgerEvent.stableType(): StableConversationLedgerEventType? =
    (type as? ConversationLedgerEventType.Known)?.stable

private fun JsonObject.toolIdentity(): String = listOf(
    text("modelTurnId"), text("toolCallId"), text("toolName"), text("ordinal")
).joinToString(":")

private fun JsonObject.toCallSpec(): CallSpecPayload = CallSpecPayload(
    phoneNumber = text("phoneNumber"),
    scene = text("scene"),
    targetName = text("targetName"),
    primaryGoal = text("primaryGoal"),
    summaryLines = stringList("summaryLines"),
    negotiationRules = stringList("negotiationRules").takeIf(List<String>::isNotEmpty),
    boundaries = stringList("boundaries").takeIf(List<String>::isNotEmpty),
)

private fun JsonObject.objectField(name: String): JsonObject? =
    get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonObject }?.asJsonObject

private fun JsonObject.text(name: String): String =
    get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonPrimitive }?.asString.orEmpty()

private fun JsonObject.stringList(name: String): List<String> =
    get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonArray }?.asJsonArray
        ?.stringValues().orEmpty()

private fun JsonArray.stringValues(): List<String> = mapNotNull { value ->
    value.takeUnless { it.isJsonNull }?.takeIf { it.isJsonPrimitive }?.asString?.takeIf(String::isNotBlank)
}
