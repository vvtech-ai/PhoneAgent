package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PartialToolCall
import com.vvtech.aiassistant.features.assistant.VoiceRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceConversationStepProjectorTest {
    @Test
    fun liveMakeCallKeepsAiNarrativeAndOneConfirmationWithoutToolBackfillCards() {
        val spec = callSpec()
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("帮我订今晚的四人位"),
                assistant(
                    text = "信息已经整理好了，请确认。",
                    callConfirmSpec = spec,
                    partialToolCalls = listOf(
                        PartialToolCall(
                            id = "tool-call-1",
                            name = "makeCall",
                            argsPreview = "",
                            result = "已完成",
                        )
                    ),
                    toolCalls = listOf(ToolCallInfo("makeCall", "", "已完成")),
                    toolCards = listOf(
                        ToolCardInfo(
                            id = "tool-call-1",
                            toolName = "makeCall",
                            methodLabel = "make_call()",
                            result = "已完成",
                        )
                    ),
                ),
            )
        )

        assertEquals(2, projection.size)
        val displayed = projection.last()
        assertEquals("信息已经整理好了，请确认。", displayed.text)
        assertEquals(spec, displayed.callConfirmSpec)
        assertTrue(displayed.partialToolCalls.isEmpty())
        assertNull(displayed.toolCalls)
        assertTrue(displayed.toolCards.isEmpty())
        assertEquals(1, projection.count { it.callConfirmSpec != null })
    }

    @Test
    fun restoredConfirmationBeforeNarrativeBecomesOneOrderedAssistantStep() {
        val spec = callSpec()
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("帮我订餐"),
                assistant(thinking = "正在整理任务信息", callConfirmSpec = spec),
                assistant(text = "信息已经整理好了，请确认。"),
            )
        )

        assertEquals(2, projection.size)
        assertEquals("信息已经整理好了，请确认。", projection[1].text)
        assertEquals(spec, projection[1].callConfirmSpec)
        assertEquals("正在整理任务信息", projection[1].thinking)
    }

    @Test
    fun identicalConfirmationInLaterUserTurnRemainsVisible() {
        val spec = callSpec()
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("第一次确认"),
                assistant(callConfirmSpec = spec),
                user("我改完后再确认一次"),
                assistant(callConfirmSpec = spec),
            )
        )

        assertEquals(4, projection.size)
        assertEquals(2, projection.count { it.callConfirmSpec == spec })
    }

    @Test
    fun differentConfirmationsWithSameNarrativeInOneTurnBothRemainVisible() {
        val first = callSpec()
        val second = first.copy(targetName = "星河店二店")

        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("分别确认两家门店"),
                assistant(text = "请确认任务。", callConfirmSpec = first),
                assistant(text = "请确认任务。", callConfirmSpec = second),
            )
        )

        assertEquals(listOf(first, second), projection.mapNotNull { it.callConfirmSpec })
    }

    @Test
    fun baseReceiptsKeepDifferentOutcomesAndRemoveOnlyExactDuplicate() {
        val completed = CallResultPayload("COMPLETED", "任务完成", "已经预订成功")
        val failed = CallResultPayload("FAILED", "任务未完成", "商家无人接听")

        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("执行两项任务"),
                assistant(callResult = completed),
                assistant(callResult = completed),
                assistant(callResult = failed),
            )
        )

        assertEquals(listOf(completed, failed), projection.mapNotNull { it.callResult })
    }

    @Test
    fun updatedBatchReceiptReplacesEarlierPresentationForTheSameBatch() {
        val initial = BatchCallResultPayload(
            status = "RUNNING",
            headline = "批量任务执行中",
            items = listOf(
                BatchCallItemResultPayload(
                    itemId = "item-1",
                    targetName = "星河店",
                    phoneNumber = "13800138000",
                    status = "ACTIVE",
                    headline = "正在外呼",
                    detail = "",
                    attemptCount = 1,
                    recalled = false,
                    abnormal = false,
                )
            ),
        )
        val completed = initial.copy(
            status = "PARTIAL_FAIL",
            headline = "批量任务已结束",
            items = initial.items.map {
                it.copy(phoneNumber = "", status = "FAILED", headline = "未完成", detail = "无人接听", abnormal = true)
            },
        )

        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("批量联系"),
                assistant(batchCallResult = initial),
                assistant(batchCallResult = completed),
            )
        )

        assertEquals(listOf(completed), projection.mapNotNull { it.batchCallResult })
    }

    @Test
    fun showOptionsDeduplicatesInsideEachTurnButNeverAcrossTurns() {
        val firstCard = showOptionsCard("options-1")
        val secondCard = showOptionsCard("options-2")
        val generic = "搜到的结果\n1. 星河店\n2. 科技园店"
        val narrated = "附近有两家门店\n1. 星河店\n2. 科技园店"
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("第一次搜索"),
                assistant(text = generic, toolCards = listOf(firstCard)),
                assistant(text = narrated),
                user("再搜一次"),
                assistant(text = generic, toolCards = listOf(secondCard)),
                assistant(text = narrated),
            )
        )

        assertEquals(
            listOf("第一次搜索", narrated, "再搜一次", narrated),
            projection.map(ClarificationStep::text),
        )
        assertEquals(listOf(firstCard), projection[1].toolCards)
        assertEquals(listOf(secondCard), projection[3].toolCards)
    }

    @Test
    fun contactShowOptionsKeepsOneLivePresentationAfterTimelineBackfill() {
        val card = showOptionsCard("contact-options")
        val timelineText = "选择巴鲁灵的号码\n1. 巴鲁灵 (18813004741)\n2. 巴鲁灵 (18813224741)"
        val liveText = "选择联系人\n1. 巴鲁灵（尾号 4741）\n2. 巴鲁灵（尾号 4741）"
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                user("通知周方朵和巴鲁灵开会"),
                assistant(text = timelineText),
                assistant(text = liveText, toolCards = listOf(card)),
            )
        )

        assertEquals(
            listOf("通知周方朵和巴鲁灵开会", liveText),
            projection.map(ClarificationStep::text),
        )
        assertEquals(listOf(card), projection.last().toolCards)
    }

    @Test
    fun terminalToolBackfillUsesAiBubbleWhileStreamingKeepsOneProgressItem() {
        val terminal = PureVoiceConversationStepProjector.project(
            listOf(
                assistant(
                    text = "已经找到两家门店。",
                    partialToolCalls = listOf(completedSearchPartial()),
                    toolCalls = listOf(ToolCallInfo("search", "", "已完成")),
                    toolCards = listOf(
                        ToolCardInfo(
                            id = "search-1",
                            toolName = "search",
                            methodLabel = "search()",
                            result = "找到两家门店",
                        )
                    ),
                )
            )
        ).single()

        assertEquals("已经找到两家门店。", terminal.text)
        assertTrue(terminal.partialToolCalls.isEmpty())
        assertNull(terminal.toolCalls)
        assertTrue(terminal.toolCards.isEmpty())

        val streaming = PureVoiceConversationStepProjector.project(
            listOf(
                assistant(
                    streaming = true,
                    partialToolCalls = listOf(completedSearchPartial()),
                    toolCalls = listOf(ToolCallInfo("search", "", "已完成")),
                )
            )
        ).single()

        assertEquals(1, streaming.partialToolCalls.size)
        assertNull(streaming.toolCalls)
    }

    @Test
    fun terminalToolBackfillWithoutNarrativeDoesNotLeakAsAConversationCard() {
        val projection = PureVoiceConversationStepProjector.project(
            listOf(
                assistant(
                    partialToolCalls = listOf(completedSearchPartial()),
                    toolCalls = listOf(ToolCallInfo("search", "", "已完成")),
                    toolCards = listOf(
                        ToolCardInfo(
                            id = "search-1",
                            toolName = "search",
                            methodLabel = "search()",
                            result = "找到两家门店",
                        )
                    ),
                )
            )
        )

        assertTrue(projection.isEmpty())
    }

    private fun user(text: String) = ClarificationStep(
        role = VoiceRole.User,
        text = text,
        status = "",
    )

    private fun assistant(
        text: String = "",
        callConfirmSpec: CallSpecPayload? = null,
        callResult: CallResultPayload? = null,
        batchCallResult: BatchCallResultPayload? = null,
        thinking: String? = null,
        partialToolCalls: List<PartialToolCall> = emptyList(),
        toolCalls: List<ToolCallInfo>? = null,
        toolCards: List<ToolCardInfo> = emptyList(),
        streaming: Boolean = false,
    ) = ClarificationStep(
        role = VoiceRole.Assistant,
        text = text,
        status = "",
        callConfirmSpec = callConfirmSpec,
        callResult = callResult,
        batchCallResult = batchCallResult,
        thinking = thinking,
        partialToolCalls = partialToolCalls,
        toolCalls = toolCalls,
        toolCards = toolCards,
        streaming = streaming,
    )

    private fun callSpec() = CallSpecPayload(
        phoneNumber = "13800138000",
        scene = "restaurant_booking",
        targetName = "星河店",
        primaryGoal = "今晚八点预订四人位",
        summaryLines = listOf("人数：4", "时间：今晚八点"),
    )

    private fun showOptionsCard(id: String) = ToolCardInfo(
        id = id,
        toolName = "showOptions",
        methodLabel = "showOptions()",
        result = "展示两个选项",
        status = "completed",
    )

    private fun completedSearchPartial() = PartialToolCall(
        id = "search-1",
        name = "search",
        argsPreview = "",
        result = "已完成",
    )
}
