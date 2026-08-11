package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamPlaceholderStepReducerTest {
    @Test
    fun removesRecoverablePlaceholderWithoutToolOrCallSpec() {
        val placeholder = step(text = "", streaming = true)
        val existing = step(text = "已有内容")

        val cleared = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(
            steps = listOf(existing, placeholder),
            stepIndex = 1
        )

        assertEquals(listOf(existing), cleared)
    }

    @Test
    fun stopsStreamingInsteadOfRemovingWhenPlaceholderHasToolOrCallSpec() {
        val withToolCall = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(
            steps = listOf(
                step(
                    streaming = true,
                    toolCalls = listOf(ToolCallInfo(name = "search", args = "{}", result = "ok"))
                )
            ),
            stepIndex = 0
        ).single()
        assertFalse(withToolCall.streaming)
        assertEquals(1, withToolCall.toolCalls?.size)

        val withToolCard = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(
            steps = listOf(
                step(
                    streaming = true,
                    toolCards = listOf(ToolCardInfo(toolName = "lookup", methodLabel = "查询"))
                )
            ),
            stepIndex = 0
        ).single()
        assertFalse(withToolCard.streaming)
        assertEquals(1, withToolCard.toolCards.size)

        val withCallSpec = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(
            steps = listOf(step(streaming = true, callConfirmSpec = callSpec())),
            stepIndex = 0
        ).single()
        assertFalse(withCallSpec.streaming)
        assertEquals(callSpec(), withCallSpec.callConfirmSpec)
    }

    @Test
    fun ignoresOutOfRangePlaceholderIndex() {
        val steps = listOf(step(text = "a"))
        val cleared = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(steps, -1)

        assertSame(steps, cleared)
    }

    @Test
    fun appliesErrorPlaceholderOnlyWhenTextIsBlank() {
        val blank = AgentStreamPlaceholderStepReducer.applyErrorPlaceholder(
            step = step(text = ""),
            safeErrorText = "网络异常"
        )
        assertEquals("（网络异常）", blank.text)

        val existing = AgentStreamPlaceholderStepReducer.applyErrorPlaceholder(
            step = step(text = "已有回答"),
            safeErrorText = "网络异常"
        )
        assertEquals("已有回答", existing.text)
    }

    @Test
    fun createsFreshRetryStep() {
        val retry = AgentStreamPlaceholderStepReducer.newRetryStep(nowMs = 1234L)

        assertEquals(VoiceRole.Assistant, retry.role)
        assertEquals("", retry.text)
        assertEquals("", retry.status)
        assertTrue(retry.streaming)
        assertEquals(1234L, retry.thinkingStartedAt)
    }

    @Test
    fun agentStreamHandlerDelegatesPlaceholderReducer() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val failureRecoveryHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamFailureRecoveryHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(failureRecoveryHandler.contains("AgentStreamPlaceholderStepReducer.applyErrorPlaceholder"))
        assertTrue(failureRecoveryHandler.contains("AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder"))
        assertTrue(failureRecoveryHandler.contains("AgentStreamPlaceholderStepReducer.newRetryStep"))
        assertTrue(handler.contains("AgentStreamFailureRecoveryHandler("))
        assertFalse(handler.contains("AgentStreamPlaceholderStepReducer.applyErrorPlaceholder"))
        assertFalse(handler.contains("AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder"))
        assertFalse(handler.contains("AgentStreamPlaceholderStepReducer.newRetryStep"))

        assertFalse(handler.contains("val canRemove = step.toolCalls.isNullOrEmpty()"))
        assertFalse(handler.contains("removeAt(stepIndex)"))
        assertFalse(handler.contains("step.copy(text = if (step.text.isBlank())"))
    }

    private fun step(
        text: String = "",
        streaming: Boolean = false,
        toolCalls: List<ToolCallInfo>? = null,
        toolCards: List<ToolCardInfo> = emptyList(),
        callConfirmSpec: CallSpecPayload? = null
    ): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = text,
            status = "",
            streaming = streaming,
            toolCalls = toolCalls,
            toolCards = toolCards,
            callConfirmSpec = callConfirmSpec
        )
    }

    private fun callSpec(): CallSpecPayload {
        return CallSpecPayload(
            phoneNumber = "10086",
            scene = "booking",
            targetName = "北海渔村",
            primaryGoal = "订包间",
            summaryLines = listOf("订一个包间")
        )
    }
}
