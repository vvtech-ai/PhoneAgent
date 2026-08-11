package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class AgentStreamEventHandlerTest {
    @Test
    fun textDeltaMutatesStepAndStreamsTtsDelta() {
        val harness = Harness()

        harness.handler.apply(0, AgentStreamEvent.TextDelta("hello"))

        assertEquals("hello", harness.steps[0].text)
        assertTrue(harness.events.contains("ttsDelta:hello"))
    }

    @Test
    fun statusDeltaUpdatesBatchProgressStepAndUiStatus() {
        val harness = Harness(state = Index9AssistantUiState(processingTurn = false))

        harness.handler.apply(
            0,
            AgentStreamEvent.StatusDelta(
                text = "正在拨打",
                batchId = "batch-1",
                itemIndex = 1,
                total = 2,
                targetName = "北海渔村",
                progressOnly = true
            )
        )

        assertTrue(harness.events.contains("batchProgress:正在拨打"))
        assertEquals(listOf("正在拨打"), harness.steps[0].callStatusEvents)
        assertEquals("正在拨打", harness.state.status)
        assertTrue(harness.state.processingTurn)
    }

    @Test
    fun signalAppliesResponseWithoutTtsSignal() {
        val harness = Harness()

        harness.handler.apply(0, AgentStreamEvent.Signal(response(type = "TEXT_REPLY", text = "signal text")))

        assertEquals("signal text", harness.steps[0].text)
        assertFalse(harness.events.any { it.startsWith("ttsSignal:") })
        assertTrue(harness.events.contains("response:TEXT_REPLY"))
    }

    @Test
    fun finalTextReplySignalsTtsThenFinalizesAndAppliesResponseState() {
        val harness = Harness()

        harness.handler.apply(0, AgentStreamEvent.Final(response(type = "TEXT_REPLY", text = "done")))

        assertEquals("done", harness.steps[0].text)
        assertFalse(harness.steps[0].streaming)
        assertEquals(
            listOf("cancelProgress", "mutate:done", "ttsSignal:done", "finalize:0", "response:TEXT_REPLY"),
            harness.events.filter {
                it == "cancelProgress" ||
                    it.startsWith("mutate:") ||
                    it.startsWith("ttsSignal:") ||
                    it.startsWith("finalize:") ||
                    it.startsWith("response:")
            }
        )
    }

    @Test
    fun nonVoiceErrFinalizesAndWritesStreamError() {
        val harness = Harness(voiceMode = false, state = Index9AssistantUiState(processingTurn = true))

        harness.handler.apply(0, AgentStreamEvent.Err("bad"))

        assertTrue(harness.events.contains("cancelProgress"))
        assertTrue(harness.events.contains("finalize:0"))
        assertEquals("bad", harness.state.error)
        assertEquals("bad", harness.state.status)
        assertFalse(harness.state.processingTurn)
    }

    @Test
    fun structuredNonNetworkFailureKeepsBackendDisplayMessage() {
        val harness = Harness(voiceMode = false, state = Index9AssistantUiState(processingTurn = true))

        harness.handler.apply(
            0,
            AgentStreamEvent.Err(
                message = "服务暂时不可用，请稍后再试",
                errorCode = "MODEL_PROVIDER_UNAVAILABLE",
                category = "MODEL",
                retryable = true
            )
        )

        assertEquals("服务暂时不可用，请稍后再试", harness.state.error)
        assertFalse(harness.state.processingTurn)
    }

    @Test
    fun voiceErrThrowsToUpperRecovery() {
        val harness = Harness(voiceMode = true)

        try {
            harness.handler.apply(0, AgentStreamEvent.Err("voice bad"))
            fail("voice Err should throw to upper stream recovery")
        } catch (expected: IllegalStateException) {
            assertEquals("voice bad", expected.message)
        }

        assertFalse(harness.events.contains("finalize:0"))
        assertTrue(harness.events.contains("voiceFail:voice bad"))
    }

    @Test
    fun activeBatchDoneAppliesSyncPendingAndRefreshesConversations() {
        val harness = Harness(
            state = Index9AssistantUiState(processingTurn = true, error = "old"),
            activeBatchStep = true
        )

        harness.handler.apply(0, AgentStreamEvent.Done)

        assertEquals(
            listOf("finalize:0", "clearBatch", "stopApi", "state:多路外呼结果同步中，请稍后刷新:false", "loadConversations"),
            harness.events.filter {
                it.startsWith("finalize:") ||
                    it == "clearBatch" ||
                    it == "stopApi" ||
                    it.startsWith("state:") ||
                    it == "loadConversations"
            }
        )
        assertEquals("多路外呼结果同步中，请稍后刷新", harness.state.status)
        assertEquals("old", harness.state.error)
    }

    @Test
    fun heartbeatOnlyEmitsDiagnosticLog() {
        val harness = Harness()

        harness.handler.apply(0, AgentStreamEvent.Heartbeat)

        assertEquals(listOf("logTts:applyStreamEvent type=Heartbeat step=0 voice=false"), harness.events)
    }

    @Test
    fun agentStreamHandlerDelegatesStreamEventDispatcher() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val eventHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamEventHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamEventHandler"))
        assertTrue(handler.contains("streamEventHandler.apply(stepIndex, ev)"))
        assertFalse(handler.contains("when (ev)"))
        assertTrue(eventHandler.contains("when (event)"))
        assertFalse(eventHandler.contains("AssistantViewModel"))
    }

    private class Harness(
        var state: Index9AssistantUiState = Index9AssistantUiState(),
        private val voiceMode: Boolean = false,
        activeBatchStep: Boolean = false
    ) {
        val events = mutableListOf<String>()
        val steps = mutableListOf(step())
        private var batchStepActive = activeBatchStep

        val handler = AgentStreamEventHandler(
            runtime = AgentStreamEventRuntimeCallbacks(
                isVoiceMode = { voiceMode },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                cancelTextProcessingStatusProgress = { events += "cancelProgress" },
                updateState = { reducer ->
                    state = reducer(state)
                    events += "state:${state.status}:${state.processingTurn}"
                },
                stopApiListening = { events += "stopApi" },
                loadConversations = { events += "loadConversations" },
                logTts = { events += "logTts:$it" },
                logStream = { events += "logStream:$it" }
            ),
            steps = AgentStreamEventStepCallbacks(
                mutateStep = { index, mutator ->
                    steps[index] = mutator(steps[index])
                    events += "mutate:${steps[index].text}"
                },
                finalizeStep = { index ->
                    steps[index] = steps[index].copy(streaming = false)
                    events += "finalize:$index"
                },
                responseStepInput = { response, displayText, _ ->
                    AgentStreamResponseStepInput(
                        response = response,
                        displayText = displayText
                    )
                }
            ),
            voice = AgentStreamEventVoiceCallbacks(
                maybeTtsDelta = { events += "ttsDelta:$it" },
                maybeTtsSignal = { events += "ttsSignal:$it" },
                failVoiceStream = {
                    events += "voiceFail:${it.message}"
                    throw IllegalStateException(it.message)
                }
            ),
            batch = AgentStreamEventBatchCallbacks(
                markActiveStream = { _, _, _ -> events += "markBatch" },
                holdUiForActiveStream = { events += "holdBatch" },
                applyProgress = { _, _, text -> events += "batchProgress:$text" },
                isActiveStep = { index -> batchStepActive && index == 0 },
                clearActiveState = {
                    batchStepActive = false
                    events += "clearBatch"
                },
                syncPendingStatusText = { "多路外呼结果同步中，请稍后刷新" }
            ),
            response = AgentStreamEventResponseCallbacks(
                applyResponseState = { events += "response:${it.type}" }
            )
        )
    }

    private companion object {
        fun step(): ClarificationStep {
            return ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
                streaming = true
            )
        }

        fun response(type: String, text: String?): AgentChatResponse {
            return AgentChatResponse(
                sessionId = "s1",
                type = type,
                text = text
            )
        }

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
