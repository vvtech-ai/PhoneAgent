package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamBatchCallRuntimeHandlerTest {
    @Test
    fun markAndClearDriveAudioSuppressionOnlyWhenActive() {
        val recorder = Recorder()
        val handler = recorder.handler()

        handler.markStream(stepIndex = 2, batchId = "batch-1", total = 2)

        assertTrue(handler.isActive())
        assertTrue(handler.isActiveStep(2))
        assertEquals("batch-1", handler.currentBatchId())
        assertEquals(listOf("begin:batch_call_stream_started"), recorder.audioEvents)

        handler.clear()
        handler.clear()

        assertFalse(handler.isActive())
        assertEquals(
            listOf("begin:batch_call_stream_started", "end:batch_call_stream_finished"),
            recorder.audioEvents
        )
    }

    @Test
    fun holdUiKeepsBatchCallExecutionState() {
        val recorder = Recorder(
            state = Index9AssistantUiState(
                listening = true,
                voiceConnecting = true,
                voiceActive = true,
                voiceManuallyPaused = true,
                voiceBackgroundPaused = true,
                apiAsrListening = true,
                apiAsrPartialText = "partial",
                apiTtsPlaying = true,
                localTtsSpeaking = true,
                error = "boom"
            )
        )
        val handler = recorder.handler()

        handler.holdUi()

        assertEquals(listOf("begin:batch_call_stream_active"), recorder.audioEvents)
        assertEquals(1, recorder.cancelProgressCount)
        assertTrue(recorder.state.processingTurn)
        assertFalse(recorder.state.listening)
        assertFalse(recorder.state.voiceConnecting)
        assertFalse(recorder.state.voiceActive)
        assertFalse(recorder.state.voiceManuallyPaused)
        assertFalse(recorder.state.voiceBackgroundPaused)
        assertFalse(recorder.state.apiAsrListening)
        assertNull(recorder.state.apiAsrPartialText)
        assertFalse(recorder.state.apiTtsPlaying)
        assertFalse(recorder.state.localTtsSpeaking)
        assertNull(recorder.state.error)
        assertEquals("正在执行多路外呼，完成后会汇总结果", recorder.state.status)
    }

    @Test
    fun applyProgressHoldsUiAndWritesSnapshotToStep() {
        val recorder = Recorder(
            state = Index9AssistantUiState(clarificationSteps = listOf(step()))
        )
        val handler = recorder.handler()

        handler.applyProgress(
            stepIndex = 0,
            event = progressEvent(itemIndex = 1, targetName = "张三", status = "SUCCESS"),
            text = "张三已确认"
        )

        assertEquals(
            listOf("begin:batch_call_stream_started", "begin:batch_call_stream_active"),
            recorder.audioEvents
        )
        assertTrue(handler.isActive())
        assertEquals(0, recorder.mutateCount)
        assertEquals(1, recorder.state.timelineItems.size)
        assertEquals("batch:batch-1", recorder.state.timelineItems.single().itemId)
        val snapshot = recorder.state.clarificationSteps.first().batchCallResult
        assertNotNull(snapshot)
        requireNotNull(snapshot)
        assertEquals("RUNNING", snapshot.status)
        assertEquals(listOf("张三"), snapshot.items.map { it.targetName })
    }

    @Test
    fun buildFinalPatchUsesActiveSnapshotFallback() {
        val recorder = Recorder(
            state = Index9AssistantUiState(clarificationSteps = listOf(step(text = "")))
        )
        val handler = recorder.handler()
        handler.applyProgress(
            stepIndex = 0,
            event = progressEvent(itemIndex = 1, targetName = "李四", status = "CALLING"),
            text = "正在拨打李四"
        )

        val patch = handler.buildFinalStepPatch(
            step = recorder.state.clarificationSteps.first(),
            payloadText = "批量外呼进行中：1 路执行中",
            payloadBatchCallResult = null
        )

        assertEquals("批量外呼进行中：1 路执行中", patch.text)
        assertNotNull(patch.batchCallResult)
        requireNotNull(patch.batchCallResult)
        assertEquals(listOf("李四"), patch.batchCallResult.items.map { it.targetName })
        assertTrue(patch.callStatusEvents.isEmpty())
    }

    @Test
    fun agentStreamHandlerDelegatesBatchRuntimeHandler() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamBatchCallRuntimeHandler"))
        assertTrue(handler.contains("markActiveStream = batchCallRuntimeHandler::markStream"))
        assertTrue(handler.contains("applyProgress = batchCallRuntimeHandler::applyProgress"))
        assertTrue(handler.contains("batchCallFinalStepPatch = batchCallRuntimeHandler::buildFinalStepPatch"))
        assertFalse(handler.contains("private fun hasActiveBatchCallStream("))
        assertFalse(handler.contains("private fun markActiveBatchCallStream("))
        assertFalse(handler.contains("private fun clearActiveBatchCallState("))
        assertFalse(handler.contains("private fun holdUiForActiveBatchCall("))
        assertFalse(handler.contains("private fun applyBatchCallProgress("))
        assertFalse(handler.contains("private fun batchCallFinalStepPatch("))
        assertFalse(handler.contains("AgentStreamBatchCallActiveStateHolder()"))
        assertFalse(handler.contains("activeBatchCallState."))
        assertFalse(handler.contains("beginOutboundCallAudioSuppression(\"batch_call_stream_started\")"))
        assertFalse(handler.contains("status = \"正在执行多路外呼，完成后会汇总结果\""))
    }

    private class Recorder(
        var state: Index9AssistantUiState = Index9AssistantUiState()
    ) {
        val audioEvents = mutableListOf<String>()
        var cancelProgressCount = 0
        var mutateCount = 0

        fun handler(): AgentStreamBatchCallRuntimeHandler {
            return AgentStreamBatchCallRuntimeHandler(
                callbacks = AgentStreamBatchCallRuntimeCallbacks(
                    beginOutboundCallAudioSuppression = { reason -> audioEvents += "begin:$reason" },
                    endOutboundCallAudioSuppression = { reason -> audioEvents += "end:$reason" },
                    cancelTextProcessingStatusProgress = { cancelProgressCount++ },
                    updateUiState = { reducer -> state = reducer(state) },
                    mutateStep = { index, mutator ->
                        if (index in state.clarificationSteps.indices) {
                            mutateCount++
                            val nextSteps = state.clarificationSteps.toMutableList().apply {
                                this[index] = mutator(this[index])
                            }
                            state = state.copy(clarificationSteps = nextSteps)
                        }
                    }
                )
            )
        }
    }

    private fun step(text: String = ""): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = text,
            status = "",
            callStatusEvents = listOf("正在拨打")
        )
    }

    private fun progressEvent(
        itemIndex: Int,
        targetName: String,
        status: String
    ): AgentStreamEvent.StatusDelta {
        return AgentStreamEvent.StatusDelta(
            text = status,
            batchId = "batch-1",
            itemIndex = itemIndex,
            total = 2,
            targetName = targetName,
            phoneNumber = "1380013800$itemIndex",
            batchStatus = status,
            progressOnly = true
        )
    }
}
