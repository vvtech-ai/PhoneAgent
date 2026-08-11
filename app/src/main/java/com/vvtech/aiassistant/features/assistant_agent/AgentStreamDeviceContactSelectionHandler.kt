package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal data class AgentStreamDeviceContactSelectionRuntime(
    val stateProvider: () -> Index9AssistantUiState,
    val sessionIdProvider: () -> String?,
    val isVoiceMode: () -> Boolean,
    val scope: CoroutineScope,
    val userIdProvider: () -> String
)

internal data class AgentStreamDeviceContactSelectionCallbacks(
    val clearWithoutPendingTool: () -> Unit,
    val showSelection: (DeviceContactSelectionUiState, String) -> Unit,
    val prepareSubmitting: (String) -> Unit,
    val appendUserStep: (String) -> Unit,
    val appendAssistantPlaceholder: () -> Int,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val startApiListening: () -> Unit
)

internal class AgentStreamDeviceContactSelectionHandler(
    private val runtime: AgentStreamDeviceContactSelectionRuntime,
    private val callbacks: AgentStreamDeviceContactSelectionCallbacks,
    private val submitter: AgentStreamContactLookupResultSubmitter
) {
    fun onResolved(
        results: List<Map<String, Any?>>,
        echoText: String? = null,
        pendingSelection: DeviceContactSelectionUiState? = null
    ) {
        val sessionId = runtime.sessionIdProvider() ?: return
        val pendingToolCallId = runtime.stateProvider().agentPendingToolCallId
        if (pendingToolCallId.isNullOrBlank()) {
            callbacks.clearWithoutPendingTool()
            return
        }
        if (pendingSelection != null) {
            callbacks.showSelection(pendingSelection, SelectContactStatus)
            restartContactSelectionListeningIfNeeded()
            return
        }
        if (!echoText.isNullOrBlank()) {
            callbacks.appendUserStep(echoText)
        }
        callbacks.prepareSubmitting(SubmittingStatus)
        val placeholderIndex = callbacks.appendAssistantPlaceholder()
        submitter.submitDeviceContactsLookupResult(
            AgentDeviceContactsLookupResultSubmitRequest(
                sessionId = sessionId,
                pendingToolCallId = pendingToolCallId,
                userId = runtime.userIdProvider(),
                results = results,
                channel = if (runtime.isVoiceMode()) "voice" else "text",
                placeholderIndex = placeholderIndex,
                failureMessage = SubmitFailureMessage
            )
        )
    }

    fun onConfirm(
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>,
        echoSelection: Boolean = true
    ) {
        val selection = runtime.stateProvider().agentDeviceContactSelection ?: return
        val submitResult = AgentStreamUserActionPolicy.deviceContactSelectionConfirm(
            selection = selection,
            selectedByName = selectedByName,
            echoSelection = echoSelection
        )
        onResolved(
            results = submitResult.results,
            echoText = submitResult.echoText
        )
    }

    fun tryHandleVoiceSelection(rawText: String): Boolean {
        val selection = runtime.stateProvider().agentDeviceContactSelection ?: return false
        when (val result = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, rawText)) {
            AgentDeviceContactVoiceSelectionResult.Cancel -> onCancel()
            is AgentDeviceContactVoiceSelectionResult.Invalid -> {
                applyRetryStatus(result.statusText)
                restartContactSelectionListeningIfNeeded()
            }
            is AgentDeviceContactVoiceSelectionResult.OutOfRange -> {
                applyRetryStatus(result.statusText)
                restartContactSelectionListeningIfNeeded()
            }
            is AgentDeviceContactVoiceSelectionResult.Selected -> {
                onConfirm(result.selectedByName, echoSelection = false)
            }
        }
        return true
    }

    fun onCancel() {
        val selection = runtime.stateProvider().agentDeviceContactSelection ?: return
        val submitResult = AgentStreamUserActionPolicy.deviceContactSelectionCancel(selection)
        onResolved(
            results = submitResult.results,
            echoText = submitResult.echoText
        )
    }

    private fun applyRetryStatus(statusText: String) {
        callbacks.updateState {
            it.copy(
                status = statusText,
                apiAsrPartialText = null,
                listening = false,
                apiAsrListening = false,
                voiceConnecting = false
            )
        }
    }

    private fun restartContactSelectionListeningIfNeeded() {
        if (!runtime.isVoiceMode()) return
        runtime.scope.launch {
            delay(300)
            val state = runtime.stateProvider()
            if (state.agentDeviceContactSelection != null &&
                !state.processingTurn &&
                !state.voiceManuallyPaused &&
                !state.voiceBackgroundPaused
            ) {
                callbacks.startApiListening()
            }
        }
    }

    private companion object {
        private const val SelectContactStatus = "请选择联系人，可直接说第一个、第二个"
        private const val SubmittingStatus = "AI处理中"
        private const val SubmitFailureMessage = "联系人查询回传失败"
    }
}
