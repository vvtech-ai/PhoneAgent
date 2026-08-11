package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepPatch
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamResponseStepReducerTest {
    @Test
    fun resolvesVisibleDisplayTextForResponseTypes() {
        assertEquals(
            "你好",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(response(type = "TEXT_REPLY", text = " 你好 "))
        )

        assertEquals(
            "任务确认完毕，现在帮您拨打北海渔村的电话...",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(
                response(type = "MAKE_CALL_REQUEST", text = "", callSpec = callSpec("北海渔村"))
            )
        )

        assertEquals(
            "准备拨打",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(
                response(type = "MAKE_CALL_REQUEST", text = "准备拨打", callSpec = callSpec(""))
            )
        )

        assertEquals(
            "对方连续拒接，建议稍后再试。",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(
                response(type = "CALL_RESULT", text = " 对方连续拒接，建议稍后再试。 ")
            )
        )
        assertEquals(
            "",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(
                response(type = "CALL_RESULT", text = "预订结果：未完成")
            )
        )

        val batchResult = BatchCallResultPayload(
            status = "COMPLETED",
            headline = "完成",
            items = listOf(batchItem("1", "SUCCESS"))
        )
        assertEquals(
            "批量外呼完成：1 路成功",
            AgentStreamResponseStepReducer.visibleResponseDisplayText(
                response(type = "BATCH_CALL_RESULT", text = "fallback", batchCallResult = batchResult)
            )
        )
    }

    @Test
    fun appliesRegularResponseWithoutOverwritingExistingText() {
        val filled = AgentStreamResponseStepReducer.applyResponse(
            step = step(text = ""),
            input = input(response(type = "TEXT_REPLY", text = "新文本"), displayText = "新文本")
        )
        assertEquals("新文本", filled.text)

        val preserved = AgentStreamResponseStepReducer.applyResponse(
            step = step(text = "已有文本"),
            input = input(response(type = "TEXT_REPLY", text = "新文本"), displayText = "新文本")
        )
        assertEquals("已有文本", preserved.text)
    }

    @Test
    fun appliesMakeCallSpecToStep() {
        val spec = callSpec("北海渔村")
        val updated = AgentStreamResponseStepReducer.applyResponse(
            step = step(),
            input = input(
                response = response(
                    type = "MAKE_CALL_REQUEST",
                    text = "",
                    callSpec = spec,
                    pendingToolCallId = "tool-call-1",
                ),
                displayText = "任务确认完毕，现在帮您拨打北海渔村的电话..."
            )
        )

        assertEquals(spec, updated.callConfirmSpec)
        assertEquals("tool-call-1", updated.callConfirmIdentity)
        assertEquals("任务确认完毕，现在帮您拨打北海渔村的电话...", updated.text)
    }

    @Test
    fun keepsCallResultNarrativeAndClearsTerminalThinkingLines() {
        val explanation = "对方连续拒接，可能暂时不方便接听。"
        val updated = AgentStreamResponseStepReducer.applyResponse(
            step = step(
                thinking = "计划\n通话已结束\n任务已完成\n保留"
            ),
            input = input(
                response(type = "CALL_RESULT", text = explanation),
                displayText = explanation
            )
        )

        assertEquals(explanation, updated.text)
        assertEquals("计划\n保留", updated.thinking)
    }

    @Test
    fun appliesBatchPatchOverResponseAndClearsStatusEvents() {
        val result = BatchCallResultPayload(
            status = "COMPLETED",
            headline = "完成",
            items = listOf(batchItem("1", "SUCCESS"))
        )
        val patch = TaskBatchCallFinalStepPatch(
            text = "批量外呼完成：1 路成功",
            batchCallResult = result,
            callStatusEvents = emptyList()
        )

        val updated = AgentStreamResponseStepReducer.applyResponse(
            step = step(text = "旧文本", callStatusEvents = listOf("正在拨打")),
            input = input(
                response = response(type = "BATCH_CALL_RESULT", text = "fallback"),
                displayText = "fallback",
                batchPatch = patch
            )
        )

        assertEquals("批量外呼完成：1 路成功", updated.text)
        assertSame(result, updated.batchCallResult)
        assertTrue(updated.callStatusEvents.isEmpty())
    }

    @Test
    fun includesThinkingAndToolsOnlyForPlaceholderResponse() {
        val toolCalls = listOf(ToolCallInfo(name = "search", args = "{}", result = "ok"))
        val response = response(type = "TEXT_REPLY", text = "回答", thinking = "思考", toolCalls = toolCalls)

        val streaming = AgentStreamResponseStepReducer.applyResponse(
            step = step(),
            input = input(response = response, displayText = "回答")
        )
        assertEquals(null, streaming.thinking)
        assertEquals(null, streaming.toolCalls)

        val placeholder = AgentStreamResponseStepReducer.applyResponse(
            step = step(),
            input = input(response = response, displayText = "回答", includeThinkingAndTools = true)
        )
        assertEquals("思考", placeholder.thinking)
        assertEquals(listOf(ToolCallInfo("search", "", "已完成")), placeholder.toolCalls)
    }

    @Test
    fun responseToolCallsDoNotCarryInternalPayloadIntoUiState() {
        val secretMarker = "INTERNAL_SKILL_PROMPT_MUST_NOT_RENDER"
        val response = response(
            type = "TEXT_REPLY",
            text = "回答",
            toolCalls = listOf(ToolCallInfo("activateSkill", secretMarker, secretMarker))
        )

        val updated = AgentStreamResponseStepReducer.applyResponse(
            step = step(),
            input = input(response, "回答", includeThinkingAndTools = true)
        )

        assertEquals(listOf(ToolCallInfo("activateSkill", "", "已完成")), updated.toolCalls)
        assertFalse(updated.toString().contains(secretMarker))
    }

    @Test
    fun placeholderResponseAlwaysReleasesStreamOwnershipWhenStateApplicationFails() {
        var state = Index9AssistantUiState(
            clarificationSteps = listOf(step().copy(streaming = true))
        )
        val released = mutableListOf<Int>()
        val handler = AgentStreamStepMutationHandler(
            AgentStreamStepMutationCallbacks(
                updateState = { reducer -> state = reducer(state) },
                batchCallFinalStepPatch = { _, _, _ -> null },
                maybeTtsSignal = {},
                applyAgentResponseState = { error("state application failed") },
                releaseStreamOwnership = released::add,
            )
        )

        runCatching {
            handler.fillPlaceholderWithResponse(
                stepIndex = 0,
                response = response(type = "TEXT_REPLY", text = "查询完成"),
            )
        }

        assertFalse(state.clarificationSteps.single().streaming)
        assertEquals(listOf(0), released)
    }

    @Test
    fun agentStreamHandlerDelegatesResponseStepReducer() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val stepHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamStepMutationHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.lines().size < 500)
        assertTrue(stepHandler.lines().size <= 180)
        assertTrue(handler.contains("AgentStreamStepMutationHandler("))
        assertTrue(actionGraph.contains("responseConsumer = stepMutationHandler::fillPlaceholderWithResponse"))
        assertTrue(handler.contains("responseStepInput = stepMutationHandler::responseStepInput"))
        assertFalse(handler.contains("private fun fillPlaceholderWithResponse("))
        assertFalse(handler.contains("private fun responseStepInput("))
        assertFalse(handler.contains("private fun visibleResponseDisplayText("))

        assertTrue(stepHandler.contains("AgentStreamResponseStepReducer.applyResponse"))
        assertTrue(stepHandler.contains("AgentStreamResponseStepReducer.visibleResponseDisplayText"))
        assertTrue(stepHandler.contains("AgentStreamResponseStepReducer.callConfirmSpec"))
        assertTrue(stepHandler.contains("AgentStreamResponseStepInput("))

        assertFalse(handler.contains("AgentStreamResponseStepReducer.applyResponse"))
        assertFalse(handler.contains("AgentStreamResponseStepReducer.visibleResponseDisplayText"))
        assertFalse(handler.contains("AgentStreamResponseStepReducer.callConfirmSpec"))
        assertFalse(handler.contains("AgentStreamResponseStepInput("))
        assertFalse(handler.contains("val step = ClarificationStep("))
        assertFalse(handler.contains("clarificationSteps.toMutableList()"))
        assertTrue(stepHandler.contains("val step = ClarificationStep("))
        assertTrue(stepHandler.contains("clarificationSteps.toMutableList()"))
        assertFalse(handler.contains("mergedPayloadText"))
        assertFalse(handler.contains("responseDisplayText(response"))
        assertFalse(handler.contains("withoutTerminalCallResultConversation"))
        assertFalse(handler.contains("looksLikeTerminalCallResultProgress"))
        assertFalse(handler.contains("任务确认完毕，现在帮您拨打"))
    }

    private fun input(
        response: AgentChatResponse,
        displayText: String,
        batchPatch: TaskBatchCallFinalStepPatch? = null,
        includeThinkingAndTools: Boolean = false
    ): AgentStreamResponseStepInput {
        return AgentStreamResponseStepInput(
            response = response,
            displayText = displayText,
            batchPatch = batchPatch,
            includeThinkingAndTools = includeThinkingAndTools
        )
    }

    private fun response(
        type: String,
        text: String? = null,
        thinking: String? = null,
        toolCalls: List<ToolCallInfo>? = null,
        callSpec: CallSpecPayload? = null,
        batchCallResult: BatchCallResultPayload? = null,
        pendingToolCallId: String? = null,
    ): AgentChatResponse {
        return AgentChatResponse(
            sessionId = "session",
            type = type,
            text = text,
            thinking = thinking,
            toolCalls = toolCalls,
            callSpec = callSpec,
            batchCallResult = batchCallResult,
            pendingToolCallId = pendingToolCallId,
        )
    }

    private fun step(
        text: String = "",
        thinking: String? = null,
        callStatusEvents: List<String> = emptyList()
    ): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = text,
            status = "",
            thinking = thinking,
            callStatusEvents = callStatusEvents
        )
    }

    private fun callSpec(targetName: String): CallSpecPayload {
        return CallSpecPayload(
            phoneNumber = "10086",
            scene = "booking",
            targetName = targetName,
            primaryGoal = "订包间",
            summaryLines = listOf("订一个包间")
        )
    }

    private fun batchItem(
        itemId: String,
        status: String
    ): BatchCallItemResultPayload {
        return BatchCallItemResultPayload(
            itemId = itemId,
            targetName = "目标$itemId",
            phoneNumber = "1380013800$itemId",
            status = status,
            headline = status,
            detail = status,
            attemptCount = 1,
            recalled = false,
            abnormal = false
        )
    }
}
