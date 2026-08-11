package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationBackgroundPauseReducerTest {
    @Test
    fun applyClearsVoiceRuntimeAndShowsPauseStatusWhenConversationIsVisible() {
        val state = Index9AssistantUiState(
            status = "处理中",
            clarificationSteps = listOf(ClarificationStep(VoiceRole.User, "订包间", "已识别")),
            listening = true,
            voiceConnecting = true,
            voiceActive = true,
            voiceManuallyPaused = true,
            voiceBackgroundPaused = false,
            processingTurn = true,
            loading = true,
            apiAsrListening = true,
            apiAsrPartialText = "北海渔村",
            apiTtsPlaying = true,
            localTtsSpeaking = true,
            liveUserTranscript = "用户实时文本",
            liveAssistantTranscript = "AI实时文本"
        )

        val next = TaskConversationBackgroundPauseReducer.apply(state)

        assertFalse(next.listening)
        assertFalse(next.voiceConnecting)
        assertFalse(next.voiceActive)
        assertFalse(next.voiceManuallyPaused)
        assertTrue(next.voiceBackgroundPaused)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
        assertFalse(next.apiAsrListening)
        assertNull(next.apiAsrPartialText)
        assertFalse(next.apiTtsPlaying)
        assertFalse(next.localTtsSpeaking)
        assertNull(next.liveUserTranscript)
        assertNull(next.liveAssistantTranscript)
        assertEquals("已暂停，返回后可继续", next.status)
    }

    @Test
    fun applyKeepsStatusWhenConversationHasNoVisibleSteps() {
        val state = Index9AssistantUiState(
            status = "等待输入",
            listening = true,
            voiceActive = true
        )

        val next = TaskConversationBackgroundPauseReducer.apply(state)

        assertEquals("等待输入", next.status)
        assertFalse(next.listening)
        assertFalse(next.voiceActive)
        assertTrue(next.voiceBackgroundPaused)
    }

    @Test
    fun stateHolderAppliesBackgroundPauseReducer() {
        val uiState = MutableStateFlow(
            Index9AssistantUiState(
                status = "处理中",
                clarificationSteps = listOf(ClarificationStep(VoiceRole.User, "订包间", "已识别")),
                listening = true,
                apiTtsPlaying = true
            )
        )
        val holder = TaskConversationBackgroundPauseStateHolder(uiState)

        holder.applyBackgroundPause()

        assertFalse(uiState.value.listening)
        assertFalse(uiState.value.apiTtsPlaying)
        assertTrue(uiState.value.voiceBackgroundPaused)
        assertEquals("已暂停，返回后可继续", uiState.value.status)
    }
}
