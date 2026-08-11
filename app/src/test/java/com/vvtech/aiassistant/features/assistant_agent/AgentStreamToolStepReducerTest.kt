package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PartialToolCall
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamToolStepReducerTest {
    @Test
    fun startsAndUpdatesPartialToolCallById() {
        val started = AgentStreamToolStepReducer.applyToolCallStart(
            step = step(),
            id = "tool-1",
            name = "search",
            argsPartial = "{\"q\":\"a\"}"
        )
        assertEquals(1, started.partialToolCalls.size)
        assertEquals("tool-1", started.partialToolCalls[0].id)
        assertEquals("search", started.partialToolCalls[0].name)
        assertEquals("", started.partialToolCalls[0].argsPreview)

        val updated = AgentStreamToolStepReducer.applyToolCallStart(
            step = started,
            id = "tool-1",
            name = "search",
            argsPartial = "{\"q\":\"ab\"}"
        )
        assertEquals(1, updated.partialToolCalls.size)
        assertEquals("", updated.partialToolCalls[0].argsPreview)

        val anonymous = AgentStreamToolStepReducer.applyToolCallStart(
            step = updated,
            id = "",
            name = "lookup",
            argsPartial = "{}"
        )
        assertEquals("p_1", anonymous.partialToolCalls[1].id)
    }

    @Test
    fun completesExistingAndMissingPartialToolCalls() {
        val existing = step(
            partialToolCalls = listOf(
                PartialToolCall(
                    id = "tool-1",
                    name = "search",
                    argsPreview = "{}",
                    startedAt = 100L
                )
            )
        )

        val completed = AgentStreamToolStepReducer.applyToolCallComplete(
            step = existing,
            id = "tool-1",
            name = "search",
            args = "{\"q\":\"北海\"}",
            result = "",
            nowMs = 250L
        )

        assertEquals("", completed.partialToolCalls[0].argsPreview)
        assertEquals("已完成", completed.partialToolCalls[0].result)
        assertEquals(150L, completed.partialToolCalls[0].durationMs)

        val missing = AgentStreamToolStepReducer.applyToolCallComplete(
            step = completed,
            id = "",
            name = "lookup",
            args = "{}",
            result = "done",
            nowMs = 300L
        )

        assertEquals("c_1", missing.partialToolCalls[1].id)
        assertEquals("lookup", missing.partialToolCalls[1].name)
        assertEquals("已完成", missing.partialToolCalls[1].result)
        assertEquals(0L, missing.partialToolCalls[1].durationMs)
    }

    @Test
    fun rawStreamingToolPayloadIsReplacedBeforeEnteringUiState() {
        val secretMarker = "INTERNAL_SKILL_PROMPT_MUST_NOT_RENDER"
        val started = AgentStreamToolStepReducer.applyToolCallStart(
            step = step(),
            id = "tool-secret",
            name = "activateSkill",
            argsPartial = secretMarker
        )
        val completed = AgentStreamToolStepReducer.applyToolCallComplete(
            step = started,
            id = "tool-secret",
            name = "activateSkill",
            args = secretMarker,
            result = secretMarker,
            nowMs = 200L
        )

        assertEquals("", completed.partialToolCalls.single().argsPreview)
        assertEquals("已完成", completed.partialToolCalls.single().result)
        assertFalse(completed.toString().contains(secretMarker))
    }

    @Test
    fun upsertsToolCardsByIdAndAnonymousKey() {
        val first = ToolCardInfo(id = "card-1", toolName = "search", methodLabel = "搜索", body = "a")
        val replacement = first.copy(body = "b")
        val anonymous = ToolCardInfo(toolName = "lookup", methodLabel = "查询", body = "same", result = "1")
        val anonymousReplacement = anonymous.copy(result = "2")

        val withFirst = AgentStreamToolStepReducer.applyToolCard(step(), first)
        val withReplacement = AgentStreamToolStepReducer.applyToolCard(withFirst, replacement)
        assertEquals(1, withReplacement.toolCards.size)
        assertEquals("b", withReplacement.toolCards[0].body)

        val withAnonymous = AgentStreamToolStepReducer.applyToolCard(withReplacement, anonymous)
        val withAnonymousReplacement = AgentStreamToolStepReducer.applyToolCard(withAnonymous, anonymousReplacement)
        assertEquals(2, withAnonymousReplacement.toolCards.size)
        assertEquals("2", withAnonymousReplacement.toolCards[1].result)
    }

    @Test
    fun finalizesStepCollapsingCompletedToolsAndCancellingRunningTools() {
        val existingToolCalls = listOf(ToolCallInfo(name = "old", args = "{}", result = "old"))
        val finalized = AgentStreamToolStepReducer.finalizeStep(
            step = step(
                streaming = true,
                thinking = "  ",
                toolCalls = existingToolCalls,
                thinkingStartedAt = 100L,
                partialToolCalls = listOf(
                    PartialToolCall(
                        id = "done",
                        name = "search",
                        argsPreview = "{\"q\":\"a\"}",
                        result = "ok",
                        durationMs = 20L,
                        startedAt = 120L
                    ),
                    PartialToolCall(
                        id = "running",
                        name = "lookup",
                        argsPreview = "{}",
                        startedAt = 150L
                    )
                )
            ),
            nowMs = 300L
        )

        assertFalse(finalized.streaming)
        assertEquals(200L, finalized.thinkingDurationMs)
        assertNull(finalized.thinking)
        assertEquals(2, finalized.partialToolCalls.size)
        assertEquals("（已取消）", finalized.partialToolCalls[1].result)
        assertEquals(150L, finalized.partialToolCalls[1].durationMs)
        assertEquals(listOf(ToolCallInfo("search", "", "已完成")), finalized.toolCalls)
    }

    @Test
    fun agentStreamHandlerDelegatesToolStepReducer() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val eventHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamEventHandler.kt")
                .readText(Charsets.UTF_8)
        val stepHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamStepMutationHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(stepHandler.contains("AgentStreamToolStepReducer.finalizeStep"))
        assertTrue(eventHandler.contains("AgentStreamToolStepReducer.applyToolCallStart"))
        assertTrue(eventHandler.contains("AgentStreamToolStepReducer.applyToolCallComplete"))
        assertTrue(eventHandler.contains("AgentStreamToolStepReducer.applyToolCard"))
        assertFalse(handler.contains("AgentStreamToolStepReducer.finalizeStep"))
        assertFalse(handler.contains("AgentStreamToolStepReducer.applyToolCallStart"))
        assertFalse(handler.contains("AgentStreamToolStepReducer.applyToolCallComplete"))
        assertFalse(handler.contains("AgentStreamToolStepReducer.applyToolCard"))

        assertFalse(handler.contains("upsertToolCard("))
        assertFalse(handler.contains("collapsedTools"))
        assertFalse(handler.contains("PartialToolCall("))
        assertFalse(handler.contains("result = \"（已取消）\""))
    }

    private fun step(
        streaming: Boolean = false,
        thinking: String? = null,
        toolCalls: List<ToolCallInfo>? = null,
        thinkingStartedAt: Long? = null,
        partialToolCalls: List<PartialToolCall> = emptyList()
    ): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = "",
            status = "",
            streaming = streaming,
            thinking = thinking,
            toolCalls = toolCalls,
            thinkingStartedAt = thinkingStartedAt,
            partialToolCalls = partialToolCalls
        )
    }
}
