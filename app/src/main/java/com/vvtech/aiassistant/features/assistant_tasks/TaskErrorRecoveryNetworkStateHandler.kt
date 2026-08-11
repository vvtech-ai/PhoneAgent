package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.networkTaskErrorStatusMessage

internal class TaskErrorRecoveryNetworkStateHandler(
    private val uiStateHolder: TaskErrorRecoveryUiStateHolder,
    private val pendingAiCallLaunch: () -> Boolean,
    private val currentVoiceLanguage: () -> VoiceLanguage,
    private val cancelTextProcessingStatusProgress: () -> Unit,
    private val closeTaskVoiceRealtime: (String) -> Unit,
    private val log: (String) -> Unit
) {
    fun applyNetworkTaskErrorState(raw: String? = null) {
        if (isAiCallContextActive()) {
            cancelTextProcessingStatusProgress()
            uiStateHolder.applyNetworkTaskErrorState(
                keepCallContext = true,
                message = TaskCallNetworkReconnectingStatus
            )
            log("applyNetworkTaskErrorState keep_call_context raw=${previewText(raw.orEmpty())}")
            return
        }

        val message = networkTaskErrorStatusMessage(currentVoiceLanguage())
        cancelTextProcessingStatusProgress()
        closeTaskVoiceRealtime("network_task_error")
        uiStateHolder.applyNetworkTaskErrorState(
            keepCallContext = false,
            message = message
        )
        log("applyNetworkTaskErrorState raw=${previewText(raw.orEmpty())}")
    }

    private fun isAiCallContextActive(): Boolean {
        val state = uiStateHolder.currentState()
        return state.showAiCallPage ||
            state.currentCallId?.isNotBlank() == true ||
            pendingAiCallLaunch()
    }
}

private fun previewText(text: String?, limit: Int = 48): String =
    text.orEmpty().replace("\n", " ").trim().let { if (it.length <= limit) it else it.take(limit) + "..." }
