package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamBasicStepReducerTest {
    @Test
    fun appendsThinkingWithTrimAndLineBreaks() {
        val first = AgentStreamBasicStepReducer.appendThinking(step(), "  第一段  ")
        assertEquals("第一段", first.thinking)

        val second = AgentStreamBasicStepReducer.appendThinking(first, "第二段")
        assertEquals("第一段\n第二段", second.thinking)

        assertEquals(second, AgentStreamBasicStepReducer.appendThinking(second, " "))
    }

    @Test
    fun appliesThinkingDoneAndTextDelta() {
        val withDuration = AgentStreamBasicStepReducer.applyThinkingDone(step(), 123L)
        assertEquals(123L, withDuration.thinkingDurationMs)

        val withText = AgentStreamBasicStepReducer.appendText(step(text = "你"), "好")
        assertEquals("你好", withText.text)
    }

    @Test
    fun appendsStatusEventsWithTrimDistinctAndLastEight() {
        val base = step(callStatusEvents = listOf(" 旧1 ", "旧2", "旧1", ""))
        val added = (3..11).fold(base) { current, index ->
            AgentStreamBasicStepReducer.appendStatusEvent(current, " 状态$index ")
        }
        val duplicate = AgentStreamBasicStepReducer.appendStatusEvent(added, "状态11")

        assertEquals(
            listOf("状态4", "状态5", "状态6", "状态7", "状态8", "状态9", "状态10", "状态11"),
            duplicate.callStatusEvents
        )
    }

    @Test
    fun agentStreamHandlerDelegatesBasicStepReducer() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val eventHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamEventHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(eventHandler.contains("AgentStreamBasicStepReducer.appendThinking"))
        assertTrue(eventHandler.contains("AgentStreamBasicStepReducer.appendStatusEvent"))
        assertTrue(eventHandler.contains("AgentStreamBasicStepReducer.applyThinkingDone"))
        assertTrue(eventHandler.contains("AgentStreamBasicStepReducer.appendText"))
        assertFalse(handler.contains("AgentStreamBasicStepReducer.appendThinking"))
        assertFalse(handler.contains("AgentStreamBasicStepReducer.appendStatusEvent"))

        assertFalse(handler.contains("step.thinking.orEmpty().trim()"))
        assertFalse(handler.contains("takeLast(8)"))
        assertFalse(handler.contains("step.copy(text = it.text + ev.text)"))
    }

    private fun step(
        text: String = "",
        callStatusEvents: List<String> = emptyList()
    ): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = text,
            status = "",
            callStatusEvents = callStatusEvents
        )
    }
}
