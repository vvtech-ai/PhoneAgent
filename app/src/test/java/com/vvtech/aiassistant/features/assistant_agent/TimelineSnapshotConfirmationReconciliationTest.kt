package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceConversationStepProjector
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TimelineSnapshotConfirmationReconciliationTest {

    @Test
    fun livePreCallReplyStaysBeforeTerminalReceiptAndFinalReply() {
        val spec = callSpec(phoneNumber = "075586966889").copy(
            targetName = "北海渔村(科技生态园店)",
        )
        val preCallReply = "任务确认完毕，现在帮您拨打北海渔村(科技生态园店)的电话..."
        val finalReply = "搞定了！北海渔村科技生态园店已确认明晚8点，5位。"
        val currentState = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(VoiceRole.User, "可以直接订", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = preCallReply,
                    status = "",
                    callConfirmSpec = spec,
                    callConfirmIdentity = "tool-call-1",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "COMPLETED",
                    callResult = CallResultPayload(
                        status = "COMPLETED",
                        headline = "已确认明晚8点5位订位",
                        detail = "",
                        metadata = mapOf("callAttemptId" to "attempt-1"),
                    ),
                ),
            ),
        )
        val committedItems = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("可以直接订")),
            item(
                2,
                "confirmation",
                ConversationTimelinePayload.CallConfirmation(
                    callSpec = spec,
                    toolCallId = "tool-call-1",
                ),
            ),
            item(3, "receipt", receipt()),
            item(4, "assistant", ConversationTimelinePayload.AssistantMessage(finalReply)),
        )
        val projection = TimelineSnapshotUiProjector.project(snapshot(committedItems))

        val once = projection.reduce(currentState)
        val displayedOnce = PureVoiceConversationStepProjector.project(once.clarificationSteps)
        val confirmationIndex = displayedOnce.indexOfFirst { it.text == preCallReply }
        val receiptIndex = displayedOnce.indexOfFirst { it.callResult != null }
        val finalReplyIndex = displayedOnce.indexOfFirst { it.text == finalReply }

        assertEquals(true, confirmationIndex >= 0)
        assertEquals(true, confirmationIndex < receiptIndex)
        assertEquals(true, confirmationIndex < finalReplyIndex)
        assertEquals(1, displayedOnce.count { it.callConfirmIdentity == "tool-call-1" })

        val twice = projection.reduce(once)
        assertEquals(
            displayedOnce,
            PureVoiceConversationStepProjector.project(twice.clarificationSteps),
        )
    }

    @Test
    fun durableConfirmationUsesTheSameGeneratedTextAsTheLiveResponse() {
        val spec = callSpec(phoneNumber = "075586966889").copy(
            targetName = "北海渔村(科技生态园店)",
        )
        val committedItems = listOf(
            item(
                1,
                "confirmation",
                ConversationTimelinePayload.CallConfirmation(
                    callSpec = spec,
                    toolCallId = "tool-call-1",
                ),
            ),
        )

        val projected = TimelineSnapshotUiProjector.project(snapshot(committedItems))

        assertEquals(
            "任务确认完毕，现在帮您拨打北海渔村(科技生态园店)的电话...",
            projected.clarificationSteps.single().text,
        )
    }

    @Test
    fun sameToolCallIdKeepsOriginalConfirmationBeforeReceiptAfterLiveCompletion() {
        val committedSpec = callSpec(phoneNumber = "13800138000")
        val liveSpec = committedSpec.copy(
            phoneNumber = "尾号 8000",
            summaryLines = listOf(
                "目标：向对方问好",
                "phoneNumber：尾号 8000",
            ),
            negotiationRules = emptyList(),
            boundaries = emptyList(),
        )
        val finalNarrative = "电话已经结束，结果如下。"
        val currentState = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(VoiceRole.User, "帮我打电话向他问好", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = finalNarrative,
                    status = "",
                    callConfirmSpec = liveSpec,
                    callConfirmIdentity = "tool-call-1",
                ),
            ),
        )
        val committedItems = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我打电话向他问好")),
            item(
                2,
                "confirmation",
                ConversationTimelinePayload.CallConfirmation(
                    callSpec = committedSpec,
                    toolCallId = "tool-call-1",
                ),
            ),
            item(3, "receipt", receipt()),
            item(4, "assistant", ConversationTimelinePayload.AssistantMessage(finalNarrative)),
        )

        val reconciled = TimelineSnapshotUiProjector.project(snapshot(committedItems)).reduce(currentState)
        val displayed = PureVoiceConversationStepProjector.project(reconciled.clarificationSteps)

        val confirmationIndices = displayed.indices.filter { displayed[it].callConfirmSpec != null }
        val receiptIndex = displayed.indexOfFirst { it.callResult != null }
        assertEquals(1, confirmationIndices.size)
        assertEquals(true, confirmationIndices.single() < receiptIndex)
        assertEquals("13800138000", displayed[confirmationIndices.single()].callConfirmSpec?.phoneNumber)
        assertNull(displayed.last().callConfirmSpec)
    }

    @Test
    fun differentToolCallIdsKeepBothConfirmationsEvenWhenPhoneTailsMatch() {
        val committedSpec = callSpec(phoneNumber = "13800138000")
        val liveSpec = callSpec(phoneNumber = "13999138000")
        val currentState = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(VoiceRole.User, "连续处理两个电话任务", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callConfirmSpec = liveSpec,
                    callConfirmIdentity = "tool-call-b",
                ),
            ),
        )
        val committedItems = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("连续处理两个电话任务")),
            item(
                2,
                "confirmation-a",
                ConversationTimelinePayload.CallConfirmation(
                    callSpec = committedSpec,
                    toolCallId = "tool-call-a",
                ),
            ),
        )

        val reconciled = TimelineSnapshotUiProjector.project(snapshot(committedItems)).reduce(currentState)
        val displayed = PureVoiceConversationStepProjector.project(reconciled.clarificationSteps)
        val confirmations = displayed.filter { it.callConfirmSpec != null }

        assertEquals(2, confirmations.size)
        assertEquals(
            listOf("tool-call-a", "tool-call-b"),
            confirmations.map { it.callConfirmIdentity },
        )
        assertEquals(
            listOf("13800138000", "13999138000"),
            confirmations.map { it.callConfirmSpec?.phoneNumber },
        )
    }

    @Test
    fun pureVoiceProjectorMergesDifferentPayloadsForTheSameToolCallId() {
        val rawSpec = callSpec(phoneNumber = "13800138000")
        val maskedSpec = rawSpec.copy(
            phoneNumber = "尾号 8000",
            summaryLines = listOf("phoneNumber：尾号 8000"),
        )
        val projected = PureVoiceConversationStepProjector.project(
            listOf(
                ClarificationStep(VoiceRole.User, "打电话", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callConfirmSpec = rawSpec,
                    callConfirmIdentity = "tool-call-1",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callConfirmSpec = maskedSpec,
                    callConfirmIdentity = "tool-call-1",
                ),
            ),
        )

        val confirmations = projected.filter { it.callConfirmSpec != null }
        assertEquals(1, confirmations.size)
        assertEquals("tool-call-1", confirmations.single().callConfirmIdentity)
    }

    @Test
    fun pureVoiceProjectorKeepsIdenticalPayloadsForDifferentToolCallIds() {
        val spec = callSpec(phoneNumber = "13800138000")
        val projected = PureVoiceConversationStepProjector.project(
            listOf(
                ClarificationStep(VoiceRole.User, "连续执行两个电话任务", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callConfirmSpec = spec,
                    callConfirmIdentity = "tool-call-a",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callConfirmSpec = spec,
                    callConfirmIdentity = "tool-call-b",
                ),
            ),
        )

        assertEquals(
            listOf("tool-call-a", "tool-call-b"),
            projected.filter { it.callConfirmSpec != null }.map { it.callConfirmIdentity },
        )
    }

    private fun callSpec(phoneNumber: String) = CallSpecPayload(
        phoneNumber = phoneNumber,
        scene = "general",
        targetName = "对方",
        primaryGoal = "向对方问好",
        summaryLines = listOf(
            "目标：向对方问好",
            "phoneNumber：$phoneNumber",
        ),
        negotiationRules = null,
        boundaries = null,
    )

    private fun snapshot(items: List<ConversationTimelineItem>) = ConversationTimelineSnapshot(
        sessionId = "session-1",
        ledgerHeadSequence = items.maxOfOrNull { it.ledgerSequence ?: 0L } ?: 0L,
        events = emptyList(),
        projection = ConversationTimelineProjection(
            conversationStatus = "COMPLETED",
            conversationContinuable = true,
            pendingToolRestorable = false,
            migrationStatus = "MIGRATED",
            projectedThroughSequence = items.maxOfOrNull { it.ledgerSequence ?: 0L } ?: 0L,
        ),
        timeline = LedgerTimelineState(items = items),
    )

    private fun receipt() = ConversationTimelinePayload.SingleCallReceipt(
        callAttemptId = "attempt-1",
        receipt = TaskReceiptItemState(
            itemId = "attempt-1",
            targetName = "对方",
            status = "COMPLETED",
            headline = "通话完成",
            detail = "详情",
        ),
    )

    private fun item(
        sequence: Long,
        id: String,
        payload: ConversationTimelinePayload,
    ) = ConversationTimelineItem(
        itemId = id,
        sessionId = "session-1",
        taskId = "task-1",
        orderKey = TimelineOrderKey(0),
        payload = payload,
        ledgerSequence = sequence,
        ledgerEventId = "event-$sequence",
    )
}
