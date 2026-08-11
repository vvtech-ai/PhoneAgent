package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Test

class TimelineSnapshotTerminalPresentationPreservationTest {
    @Test
    fun terminalReceiptWithoutCurrentTurnAnchorsReturnsToLatestRestoredTurn() {
        val receipt = CallResultPayload(
            status = "FAILED",
            headline = "任务未完成",
            detail = "包房已满",
            metadata = mapOf("callAttemptId" to "attempt-late"),
        )
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                assistant(
                    text = "包房已经满了，要换大厅吗？",
                    callResult = receipt,
                )
            ),
        )

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
                    item(
                        2,
                        "assistant",
                        ConversationTimelinePayload.AssistantMessage("包房已经满了，要换大厅吗？"),
                    ),
                )
            )
        ).reduce(state)

        assertEquals(VoiceRole.User, next.clarificationSteps.first().role)
        assertEquals(receipt, next.clarificationSteps.last().callResult)
        assertEquals(2, next.clarificationSteps.size)
    }

    @Test
    fun staleSnapshotKeepsCurrentSingleReceiptAfterStreamTerminal() {
        val receipt = CallResultPayload(
            status = "COMPLETED",
            headline = "预订成功",
            detail = "已预订今晚八点四人位",
            metadata = mapOf("callAttemptId" to "attempt-1"),
        )
        val state = stateWith(
            assistant(
                text = "已经帮你订好了。",
                callResult = receipt,
            )
        )

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
                    item(
                        2,
                        "assistant",
                        ConversationTimelinePayload.AssistantMessage("已经帮你订好了。"),
                    ),
                )
            )
        ).reduce(state)

        assertEquals(1, next.clarificationSteps.count { it.callResult == receipt })
        assertEquals(receipt, next.clarificationSteps.last().callResult)
    }

    @Test
    fun staleSnapshotKeepsCurrentBatchReceiptAfterStreamTerminal() {
        val receipt = BatchCallResultPayload(
            status = "COMPLETED",
            headline = "通知完成",
            items = listOf(
                BatchCallItemResultPayload(
                    itemId = "item-1",
                    targetName = "张三",
                    phoneNumber = "",
                    status = "COMPLETED",
                    headline = "已通知",
                    detail = "对方已确认参会",
                    attemptCount = 1,
                    recalled = false,
                    abnormal = false,
                )
            ),
        )
        val state = stateWith(
            assistant(
                text = "参会人已经全部通知完成。",
                batchCallResult = receipt,
            )
        )

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("通知参会人")),
                    item(
                        2,
                        "assistant",
                        ConversationTimelinePayload.AssistantMessage("参会人已经全部通知完成。"),
                    ),
                )
            )
        ).reduce(state)

        assertEquals(1, next.clarificationSteps.count { it.batchCallResult == receipt })
        assertEquals(receipt, next.clarificationSteps.last().batchCallResult)
    }

    @Test
    fun pendingSingleSnapshotCannotReplaceCurrentTerminalReceipt() {
        val currentTerminal = singleResult("COMPLETED", "预订成功")
        val state = stateWith(assistant(text = "", callResult = currentTerminal))

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
                    item(2, "pending", singleTimelineReceipt("CALL_STARTED", "通话已开始")),
                )
            )
        ).reduce(state)

        assertEquals(
            listOf("COMPLETED"),
            next.clarificationSteps.mapNotNull { it.callResult?.status },
        )
        assertEquals("预订成功", next.clarificationSteps.last().callResult?.headline)
    }

    @Test
    fun terminalSingleSnapshotWinsAgainstCurrentPendingReceipt() {
        val currentPending = singleResult("CALL_STARTED", "通话已开始")
        val state = stateWith(assistant(text = "", callResult = currentPending))

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
                    item(2, "terminal", singleTimelineReceipt("COMPLETED", "服务端确认成功")),
                )
            )
        ).reduce(state)

        assertEquals(
            listOf("COMPLETED"),
            next.clarificationSteps.mapNotNull { it.callResult?.status },
        )
        assertEquals("服务端确认成功", next.clarificationSteps.last().callResult?.headline)
    }

    @Test
    fun durableTerminalReceiptIsCanonicalWhenCurrentTerminalDiffers() {
        val currentTerminal = singleResult("FAILED", "客户端临时结果")
        val state = stateWith(assistant(text = "", callResult = currentTerminal))

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
                    item(2, "terminal", singleTimelineReceipt("FAILED", "服务端最终结果")),
                )
            )
        ).reduce(state)

        assertEquals(1, next.clarificationSteps.count { it.callResult != null })
        assertEquals("服务端最终结果", next.clarificationSteps.last().callResult?.headline)
    }

    @Test
    fun runningBatchSnapshotCannotReplaceCurrentTerminalReceipt() {
        val currentTerminal = batchResult("COMPLETED", "通知完成")
        val state = stateWith(assistant(text = "", batchCallResult = currentTerminal))

        val next = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(1, "user", ConversationTimelinePayload.UserMessage("通知参会人")),
                    item(2, "running", batchTimelineReceipt("RUNNING", "通知进行中")),
                )
            )
        ).reduce(state)

        assertEquals(
            listOf("COMPLETED"),
            next.clarificationSteps.mapNotNull { it.batchCallResult?.status },
        )
        assertEquals("通知完成", next.clarificationSteps.last().batchCallResult?.headline)
    }

    private fun stateWith(assistant: ClarificationStep) = Index9AssistantUiState(
        clarificationSteps = listOf(
            ClarificationStep(
                role = VoiceRole.User,
                text = if (assistant.batchCallResult == null) "帮我订餐" else "通知参会人",
                status = "",
            ),
            assistant,
        ),
    )

    private fun assistant(
        text: String,
        callResult: CallResultPayload? = null,
        batchCallResult: BatchCallResultPayload? = null,
    ) = ClarificationStep(
        role = VoiceRole.Assistant,
        text = text,
        status = "",
        callResult = callResult,
        batchCallResult = batchCallResult,
    )

    private fun singleResult(status: String, headline: String) = CallResultPayload(
        status = status,
        headline = headline,
        detail = "详情",
        metadata = mapOf("callAttemptId" to "attempt-1"),
    )

    private fun batchResult(status: String, headline: String) = BatchCallResultPayload(
        status = status,
        headline = headline,
        items = listOf(
            BatchCallItemResultPayload(
                itemId = "item-1",
                targetName = "张三",
                phoneNumber = "",
                status = status,
                headline = headline,
                detail = "详情",
                attemptCount = 1,
                recalled = false,
                abnormal = false,
            )
        ),
    )

    private fun singleTimelineReceipt(status: String, headline: String) =
        ConversationTimelinePayload.SingleCallReceipt(
            callAttemptId = "attempt-1",
            receipt = TaskReceiptItemState(
                itemId = "attempt-1",
                targetName = "星河店",
                status = status,
                headline = headline,
                detail = "详情",
            ),
        )

    private fun batchTimelineReceipt(status: String, headline: String) =
        ConversationTimelinePayload.BatchCallReceipt(
            batchAttemptId = "batch-1",
            receipt = BatchTaskReceiptState(
                status = status,
                headline = headline,
                items = listOf(
                    TaskReceiptItemState(
                        itemId = "item-1",
                        targetName = "张三",
                        status = status,
                        headline = headline,
                        detail = "详情",
                    )
                ),
            ),
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

    private fun item(sequence: Long, id: String, payload: ConversationTimelinePayload) =
        ConversationTimelineItem(
            itemId = id,
            sessionId = "session-1",
            taskId = "task-1",
            orderKey = TimelineOrderKey(0),
            payload = payload,
            ledgerSequence = sequence,
            ledgerEventId = "event-$sequence",
        )
}
