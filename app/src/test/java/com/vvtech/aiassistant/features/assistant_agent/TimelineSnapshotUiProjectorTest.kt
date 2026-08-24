package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceConversationStepProjector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TimelineSnapshotUiProjectorTest {
    @Test
    fun committedReplyKeepsCurrentSessionToolCard() {
        val liveTool = ToolCallInfo(
            name = "search",
            args = "",
            result = "已完成",
        )
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "帮我查一下",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    toolCalls = listOf(liveTool),
                ),
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我查一下")),
            item(2, "assistant", ConversationTimelinePayload.AssistantMessage("已经查到了")),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        assertEquals("已经查到了", next.clarificationSteps[1].text)
        assertEquals(listOf(liveTool), next.clarificationSteps[1].toolCalls)
    }

    @Test
    fun shiftedCurrentToolStepKeepsLatestReplyAndDoesNotDuplicate() {
        val liveTool = ToolCallInfo(
            name = "search",
            args = "",
            result = "已完成",
        )
        val latestReply = ClarificationStep(
            role = VoiceRole.Assistant,
            text = "已经查到了",
            status = "最新结果",
            toolCalls = listOf(liveTool),
        )
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "帮我查一下",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "正在处理",
                    status = "",
                ),
                latestReply,
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我查一下")),
            item(2, "assistant", ConversationTimelinePayload.AssistantMessage("已经查到了")),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        val committedReplies = next.clarificationSteps.filter {
            it.role == VoiceRole.Assistant && it.text == "已经查到了"
        }
        assertEquals(1, committedReplies.size)
        assertEquals(latestReply, committedReplies.single())
    }

    @Test
    fun committedMakeCallKeepsOneConfirmationWhenLiveToolStepCarriesTheSameSpec() {
        val callSpec = CallSpecPayload(
            phoneNumber = "13800138000",
            scene = "restaurant_booking",
            targetName = "星河店",
            primaryGoal = "今晚八点预订四人位",
            summaryLines = listOf("人数：4"),
        )
        val liveTool = ToolCallInfo(
            name = "makeCall",
            args = "",
            result = "已完成",
        )
        val narrative = "信息已经整理好了，请确认。"
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "帮我订餐",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = narrative,
                    status = "",
                    toolCalls = listOf(liveTool),
                    callConfirmSpec = callSpec,
                ),
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我订餐")),
            item(2, "confirmation", ConversationTimelinePayload.CallConfirmation(callSpec)),
            item(3, "assistant", ConversationTimelinePayload.AssistantMessage(narrative)),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        assertEquals(1, next.clarificationSteps.count { it.callConfirmSpec == callSpec })
        val committedNarrative = next.clarificationSteps.single { it.text == narrative }
        assertEquals(listOf(liveTool), committedNarrative.toolCalls)
        assertNull(committedNarrative.callConfirmSpec)
    }

    @Test
    fun distinctLiveConfirmationNeverOverwritesCommittedConfirmationInTheSameTurn() {
        val committedSpec = CallSpecPayload(
            phoneNumber = "13800138000",
            scene = "restaurant_booking",
            targetName = "星河店",
            primaryGoal = "预订四人位",
            summaryLines = listOf("人数：4"),
        )
        val liveSpec = committedSpec.copy(targetName = "星河店二店")
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(VoiceRole.User, "分别确认两家门店", ""),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    toolCalls = listOf(ToolCallInfo("makeCall", "", "已完成")),
                    callConfirmSpec = liveSpec,
                ),
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("分别确认两家门店")),
            item(2, "confirmation", ConversationTimelinePayload.CallConfirmation(committedSpec)),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        assertEquals(
            listOf(committedSpec, liveSpec),
            next.clarificationSteps.mapNotNull(ClarificationStep::callConfirmSpec),
        )
    }

    @Test
    fun showOptionsSnapshotDropsGenericResultBubbleButKeepsToolCard() {
        val showOptionsCard = ToolCardInfo(
            id = "show-options-1",
            toolName = "showOptions",
            methodLabel = "showOptions()",
            result = "Observe: 展示 4 个选项",
            status = "completed",
        )
        val genericText = "搜到的结果\n1. 客家边贸城店"
        val showOptionsText = "附近华莱士门店\n1. 客家边贸城店"
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "找附近的华莱士",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = genericText,
                    status = "",
                    toolCards = listOf(showOptionsCard),
                ),
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("找附近的华莱士")),
            item(2, "show-options", ConversationTimelinePayload.AssistantMessage(showOptionsText)),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        assertEquals(
            listOf("找附近的华莱士", showOptionsText),
            next.clarificationSteps.map(ClarificationStep::text),
        )
        assertEquals(listOf(showOptionsCard), next.clarificationSteps[1].toolCards)
    }

    @Test
    fun actionEchoStaysBeforeOneMergedShowOptionsResult() {
        val showOptionsCard = ToolCardInfo(
            id = "show-options-after-permission",
            toolName = "showOptions",
            methodLabel = "showOptions()",
            result = "Observe: 展示 2 个选项",
            status = "completed",
        )
        val userRequest = "帮我找附近的餐厅"
        val permissionEcho = "已授权：location"
        val genericText = "搜到的结果\n1. 星河店\n2. 科技园店"
        val narratedText = "附近有两家餐厅\n1. 星河店\n2. 科技园店"
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(VoiceRole.User, userRequest, ""),
                ClarificationStep(
                    role = VoiceRole.User,
                    text = permissionEcho,
                    status = "",
                    isUserActionEcho = true,
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = narratedText,
                    status = "",
                    toolCards = listOf(showOptionsCard),
                ),
            ),
        )
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage(userRequest)),
            item(2, "show-options", ConversationTimelinePayload.AssistantMessage(genericText)),
        )

        val restored = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)
        val displayed = PureVoiceConversationStepProjector.project(restored.clarificationSteps)

        assertEquals(
            listOf(userRequest, permissionEcho, narratedText),
            displayed.map(ClarificationStep::text),
        )
        assertTrue(displayed[1].isUserActionEcho)
        assertEquals(listOf(showOptionsCard), displayed[2].toolCards)
        assertEquals(
            1,
            displayed.flatMap(ClarificationStep::toolCards)
                .count { it.toolName == "showOptions" },
        )
    }

    @Test
    fun staleSnapshotKeepsPendingUserTurnBeforeShowOptions() {
        val showOptionsCard = ToolCardInfo(
            id = "show-options-2",
            toolName = "showOptions",
            methodLabel = "showOptions()",
            result = "Observe: 展示 3 个选项",
            status = "completed",
        )
        val state = Index9AssistantUiState(
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "帮我搜附近的华莱士",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "第一家是客家边贸城店",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "第一家不行帮我再搜一次",
                    status = "",
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "附近其他华莱士门店",
                    status = "",
                    toolCards = listOf(showOptionsCard),
                ),
            ),
        )
        val staleCommitted = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我搜附近的华莱士")),
            item(2, "assistant", ConversationTimelinePayload.AssistantMessage("第一家是客家边贸城店")),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(staleCommitted)).reduce(state)

        assertEquals(
            listOf(
                "帮我搜附近的华莱士",
                "第一家是客家边贸城店",
                "第一家不行帮我再搜一次",
                "附近其他华莱士门店",
            ),
            next.clarificationSteps.map(ClarificationStep::text),
        )
        assertEquals(listOf(showOptionsCard), next.clarificationSteps[3].toolCards)
    }

    @Test
    fun activeStreamingStepOwnsConversationUntilTerminal() {
        val liveTool = ToolCallInfo(
            name = "search",
            args = "",
            result = "已完成",
        )
        val activeSteps = listOf(
            ClarificationStep(
                role = VoiceRole.User,
                text = "帮我查一下",
                status = "",
            ),
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "正在处理",
                status = "",
            ),
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
                toolCalls = listOf(liveTool),
                streaming = true,
            ),
        )
        val state = Index9AssistantUiState(clarificationSteps = activeSteps)
        val committed = listOf(
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我查一下")),
            item(2, "assistant", ConversationTimelinePayload.AssistantMessage("已经查到了")),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(committed)).reduce(state)

        assertEquals(activeSteps, next.clarificationSteps)
        assertEquals(committed, next.timelineItems)
    }

    @Test
    fun terminalSnapshotDerivesAllCommittedUiFieldsFromOneTimeline() {
        val items = listOf(
            item(1, "z-user", ConversationTimelinePayload.UserMessage("第一句")),
            item(2, "a-assistant", ConversationTimelinePayload.AssistantMessage("第二句")),
            item(3, "m-call", receipt("COMPLETED", "订位成功")),
        )
        val state = Index9AssistantUiState(
            currentCallId = "provider-call-1",
            executionStatus = "CALLING",
            callPageData = CallPageData("旧目标", "实时外呼", "通话中", emptyList()),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(items)).reduce(state)

        assertEquals(items, next.timelineItems)
        assertEquals("第一句", next.clarificationSteps[0].text)
        assertEquals("第二句", next.clarificationSteps[1].text)
        assertEquals("订位成功", next.clarificationSteps[2].callResult?.headline)
        assertEquals("新目标", next.callPageData.name)
        assertEquals("COMPLETED", next.callPageData.status)
        assertEquals("attempt-1", next.agentCallResult?.metadata?.get("callAttemptId"))
        assertEquals("COMPLETED", next.taskStatus)
        assertEquals("CALLING", next.executionStatus)
        assertEquals(true, next.conversationContinuable)
        assertEquals(false, next.pendingToolRestorable)
    }

    @Test
    fun nonTerminalSnapshotKeepsActiveCallTransientPageAndResult() {
        val activePage = CallPageData(
            name = "当前目标",
            sub = "13800000000",
            status = "正在请求人工接管...",
            transcript = listOf(TranscriptLine(TranscriptRole.Note, "瞬时状态")),
        )
        val activeResult = CallResultPayload("ACTIVE", "当前通话", "尚未结束")
        val state = Index9AssistantUiState(
            currentCallId = "provider-call-1",
            callPageData = activePage,
            agentCallResult = activeResult,
        )

        val next = TimelineSnapshotUiProjector.project(
            snapshot(listOf(item(1, "started", receipt("CALL_STARTED", "已接通")))),
        ).reduce(state)

        assertEquals(activePage, next.callPageData)
        assertEquals(activeResult, next.agentCallResult)
    }

    @Test
    fun nonTerminalSnapshotWithoutActiveCallClearsStaleTerminalResult() {
        val state = Index9AssistantUiState(
            currentCallId = null,
            agentCallResult = CallResultPayload("COMPLETED", "旧结果", "旧详情"),
        )

        val next = TimelineSnapshotUiProjector.project(
            snapshot(listOf(item(1, "requested", receipt("CALL_REQUESTED", "等待拨号")))),
        ).reduce(state)

        assertEquals("CALL_REQUESTED", next.callPageData.status)
        assertNull(next.agentCallResult)
    }

    @Test
    fun terminalSnapshotClearsOutcomeSyncPendingStatus() {
        val state = Index9AssistantUiState(status = callOutcomeSyncPendingStatusText())

        val next = TimelineSnapshotUiProjector.project(
            snapshot(listOf(item(1, "completed", receipt("COMPLETED", "订位成功")))),
        ).reduce(state)

        assertEquals("订位成功", next.status)
    }

    @Test
    fun terminalReceiptMustMatchTheExpectedCallAttempt() {
        val stale = TimelineSnapshotUiProjector.project(
            snapshot(
                listOf(
                    item(
                        1,
                        "old-failed",
                        receipt("FAILED", "上一次失败", callAttemptId = "attempt-old"),
                    ),
                ),
            ),
        )

        assertTrue(stale.hasTerminalCallReceipt)
        assertTrue(stale.hasTerminalCallReceipt("attempt-old"))
        assertFalse(stale.hasTerminalCallReceipt("attempt-current"))

        val current = TimelineSnapshotUiProjector.project(
            snapshot(
                stale.timelineItems + item(
                    2,
                    "current-failed",
                    receipt("FAILED", "本次失败", callAttemptId = "attempt-current"),
                ),
            ),
        )

        assertTrue(current.hasTerminalCallReceipt("attempt-current"))
    }

    @Test
    fun terminalSnapshotKeepsRepeatedLiveLinesForCanonicalCallAttempt() {
        val liveTranscript = listOf(
            TranscriptLine(TranscriptRole.Remote, "请问还有什么可以帮您？"),
            TranscriptLine(TranscriptRole.Assistant, "没有了，谢谢。"),
            TranscriptLine(TranscriptRole.Remote, "请问还有什么可以帮您？"),
            TranscriptLine(TranscriptRole.Assistant, "没有了，谢谢。"),
            TranscriptLine(TranscriptRole.Remote, "请问还有什么可以帮您？"),
            TranscriptLine(TranscriptRole.Assistant, "没有了，谢谢。"),
        )
        val online = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(
                taskId = "session-1",
                callPageData = CallPageData(
                    name = "客服",
                    sub = "10000",
                    status = "正在确认通话结果",
                    transcript = liveTranscript,
                ),
            ),
            responseSessionId = "session-1",
            callResult = CallResultPayload(
                status = "COMPLETED",
                headline = "通话已结束",
                detail = "终态详情",
                metadata = mapOf(
                    "callId" to "provider-call-1",
                    "callAttemptId" to "attempt-1",
                    "dialogueTranscript" to
                        "merchant: 请问还有什么可以帮您？\nassistant: 没有了，谢谢。",
                ),
            ),
            toolCallId = "tool-1",
        )
        val terminal = item(
            3,
            "completed",
            ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = "attempt-1",
                callId = "provider-call-1",
                receipt = TaskReceiptItemState(
                    itemId = "attempt-1",
                    targetName = "客服",
                    status = "COMPLETED",
                    headline = "通话已结束",
                    detail = "终态详情",
                    transcript =
                        "merchant: 请问还有什么可以帮您？\nassistant: 没有了，谢谢。",
                ),
            ),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(listOf(terminal))).reduce(online)

        assertEquals(liveTranscript, next.callPageData.transcript.take(liveTranscript.size))
        assertEquals("attempt-1", next.callPageData.callResult?.metadata?.get("callAttemptId"))
        assertEquals("provider-call-1", next.callPageData.callResult?.metadata?.get("callId"))
        assertEquals("provider-call-1", next.agentCallResult?.metadata?.get("callId"))
    }

    @Test
    fun meetingTerminalWithoutReceiptFieldsSurvivesAReplyOnlyProjection() {
        val online = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(
                taskId = "session-1",
                clarificationSteps = listOf(
                    ClarificationStep(
                        role = VoiceRole.Assistant,
                        text = "",
                        status = "",
                        streaming = false,
                    )
                ),
            ),
            responseSessionId = "session-1",
            callResult = CallResultPayload(
                status = "COMPLETED",
                headline = "会议通知已送达",
                detail = "老王已确认参会",
                metadata = mapOf(
                    "callId" to "meeting-call-1",
                    "callAttemptId" to "meeting-attempt-1",
                    "agentOutcome" to "SUCCESS",
                ),
                receiptFields = emptyList(),
            ),
            toolCallId = "meeting-tool-1",
        )
        val reply = item(
            22,
            "meeting-reply",
            ConversationTimelinePayload.AssistantMessage(
                "老王已确认，明天中午12点大会议室见。"
            ),
        )

        val next = TimelineSnapshotUiProjector.project(snapshot(listOf(reply))).reduce(online)

        val visibleResult = next.clarificationSteps
            .mapNotNull(ClarificationStep::callResult)
            .single()
        assertEquals("会议通知已送达", visibleResult.headline)
        assertEquals("meeting-call-1", visibleResult.metadata?.get("callId"))
        assertEquals(
            1,
            next.clarificationSteps.count {
                it.text == "老王已确认，明天中午12点大会议室见。"
            },
        )
    }

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

    private fun receipt(
        status: String,
        headline: String,
        callAttemptId: String = "attempt-1",
    ) =
        ConversationTimelinePayload.SingleCallReceipt(
            callAttemptId = callAttemptId,
            receipt = TaskReceiptItemState(
                itemId = callAttemptId,
                targetName = "新目标",
                status = status,
                headline = headline,
                detail = "详情",
            ),
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
