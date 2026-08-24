package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal object AssistantSessionTerminalResultReducer {
    fun shouldPreserveTerminalResult(
        session: AssistantSessionResponse,
        state: Index9AssistantUiState,
        pendingAiCallLaunch: Boolean
    ): Boolean {
        val sessionTaskId = session.session.taskId
        val taskMatches = sessionTaskId.isNotBlank() &&
            (state.taskId == sessionTaskId || state.taskId.isNullOrBlank())
        if (!taskMatches) return false

        return state.callPageData.transcript.any { it.role != TranscriptRole.Note } ||
            looksLikeTerminalCallStatus(state.callPageData.status) ||
            state.currentCallId != null ||
            pendingAiCallLaunch
    }

    fun reduceTerminalResult(
        state: Index9AssistantUiState,
        session: AssistantSessionResponse
    ): Index9AssistantUiState {
        val sessionStatus = session.session.taskStatus
        return state.copy(
            taskId = session.session.taskId,
            sceneType = session.session.sceneType,
            taskStatus = sessionStatus,
            stage = AssistantStage.Recognized,
            status = terminalResultStatus(sessionStatus, state.callPageData.status),
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            loading = false,
            voiceConnecting = false,
            voiceActive = false,
            voiceManuallyPaused = false,
            listening = false,
            processingTurn = false,
            error = null,
            showAiCallPage = false,
            handoffInFlight = false,
            currentCallId = null,
            callUiMode = CallUiMode.Ai
        )
    }

    fun terminalResultStatus(taskStatus: String, callStatus: String): String {
        val normalizedCallStatus = callStatus.trim()
        if (normalizedCallStatus.isNotBlank() && normalizedCallStatus != "等待发起") {
            return normalizedCallStatus
        }
        return when (taskStatus.uppercase(Locale.ROOT)) {
            "FAILED", "CANCELLED", "CANCELED" -> currentAppText("通话未完成", "Call Incomplete")
            else -> currentAppText("通话已结束", "Call Ended")
        }
    }

    private fun looksLikeTerminalCallStatus(status: String): Boolean {
        val normalizedStatus = status.trim()
        if (normalizedStatus.isBlank()) return false
        return terminalCallStatusRegex.containsMatchIn(normalizedStatus)
    }

    private val terminalCallStatusRegex = Regex(
        "已结束|通话已结束|AI代打完成|预订成功|预约成功|已预订|未完成|失败|已取消|任务部分完成|结果未确认|FAILED|COMPLETED|CANCELLED|CANCELED",
        RegexOption.IGNORE_CASE
    )
}
