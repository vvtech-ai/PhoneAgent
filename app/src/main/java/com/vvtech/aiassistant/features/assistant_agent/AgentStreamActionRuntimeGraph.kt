package com.vvtech.aiassistant.features.assistant_agent

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.appendClarificationStep
import com.vvtech.aiassistant.features.assistant.currentFreshAgentUserContext
import com.vvtech.aiassistant.features.assistant.outboundCallAudioGateSnapshot
import com.vvtech.aiassistant.features.assistant.startApiListening
import com.vvtech.aiassistant.features.assistant.startCallSessionPolling
import com.vvtech.aiassistant.features.assistant.syncConversationSnapshotForVoiceRecovery
import com.vvtech.aiassistant.features.assistant.stopCallSessionPolling
import com.vvtech.aiassistant.features.assistant.viewmodel.ContactSelectionStateHolder
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.flow.update

internal class AgentStreamActionRuntimeGraph(
    private val viewModel: AssistantViewModel,
    repository: AssistantRepository,
    private val accountIdProvider: () -> String,
    private val isVoiceMode: () -> Boolean,
    private val callResultRuntimeHandler: AgentStreamCallResultRuntimeHandler,
    private val failureRecoveryHandler: AgentStreamFailureRecoveryHandler,
    private val stepMutationHandler: AgentStreamStepMutationHandler,
    private val applyStreamEvent: (String, Int, AgentStreamEvent) -> Unit,
    private val appendStreamingAssistantStep: () -> Int,
    private val releaseStreamOwnership: (Int) -> Unit,
) {
    private val contactSelectionStateHolder = ContactSelectionStateHolder(viewModel.internalUiState)
    private val actionSubmitter = AgentStreamActionSubmitter(
        scope = viewModel.viewModelScope,
        streamUseCase = AgentStreamActionSubmitUseCase(repository),
        userContextProvider = { reason -> viewModel.currentFreshAgentUserContext(reason) },
        contextLogger = callResultRuntimeHandler::logAgentContext,
        eventConsumer = applyStreamEvent,
        failureConsumer = { sessionId, placeholderIndex, throwable, message, afterStateUpdate ->
            if (isActionSessionCurrent(sessionId)) {
                failureRecoveryHandler.handleActionFailure(
                    placeholderIndex,
                    throwable,
                    message,
                    afterStateUpdate
                )
            } else {
                ignoreDetachedActionCallback(sessionId, placeholderIndex, "failure")
            }
        },
        completedWithoutTerminalConsumer = ::handleActionCompletedWithoutTerminal
    )
    private val confirmCallHandler = AgentStreamConfirmCallHandler(
        runtime = AgentStreamConfirmCallRuntime(
            stateProvider = { viewModel.internalUiState.value },
            sessionIdProvider = { viewModel.agentSessionId },
            latestCallPageSeedProvider = { viewModel.latestCallPageSeed },
            isPendingLaunch = { viewModel.pendingAiCallLaunch },
            setPendingLaunch = { pending -> viewModel.pendingAiCallLaunch = pending },
            isVoiceMode = isVoiceMode,
            scope = viewModel.viewModelScope,
            userIdProvider = accountIdProvider
        ),
        callbacks = AgentStreamConfirmCallCallbacks(
            setLatestCallPageSeed = { nextSeed -> viewModel.latestCallPageSeed = nextSeed },
            appendUserStep = { text -> viewModel.appendClarificationStep(VoiceRole.User, text) },
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            logCallPage = { message -> AppFileLogger.i("CALL_PAGE_DIAG", message) },
            audioGateSnapshot = viewModel::outboundCallAudioGateSnapshot,
            suspendDialogAudioForCall = viewModel.voiceDuplexCoordinator::suspendDialogAudioForCall,
            startCallSessionPolling = viewModel::startCallSessionPolling,
            stopCallSessionPolling = viewModel::stopCallSessionPolling,
            appendAssistantPlaceholder = appendStreamingAssistantStep,
            submitAction = { request, onFailureBeforeHandle, beforeRecover ->
                actionSubmitter.submit(
                    request,
                    onFailureBeforeHandle = { throwable ->
                        if (isActionSessionCurrent(request.sessionId)) {
                            onFailureBeforeHandle?.invoke(throwable)
                        }
                    },
                    beforeRecover = beforeRecover
                )
            }
        )
    )
    private val normalActionSubmitHandler = AgentStreamNormalActionSubmitHandler(
        appendUserStep = { text ->
            viewModel.appendClarificationStep(
                role = VoiceRole.User,
                text = text,
                isUserActionEcho = isVoiceMode(),
            )
        },
        updateUiState = { reducer -> viewModel.internalUiState.update(reducer) },
        appendAssistantPlaceholder = appendStreamingAssistantStep,
        submitAction = { request, beforeRecover ->
            actionSubmitter.submit(request, beforeRecover = beforeRecover)
        },
        channelProvider = { if (isVoiceMode()) "voice" else "text" },
        userIdProvider = accountIdProvider
    )
    private val normalActionEntryHandler = AgentStreamNormalActionEntryHandler(
        sessionIdProvider = { viewModel.agentSessionId },
        stateProvider = { viewModel.internalUiState.value },
        updateUiState = { reducer -> viewModel.internalUiState.update(reducer) },
        submitHandler = normalActionSubmitHandler
    )
    private val contactLookupResultSubmitter = AgentStreamContactLookupResultSubmitter(
        scope = viewModel.viewModelScope,
        lookupResultUseCase = AgentStreamContactLookupResultUseCase(repository),
        responseConsumer = stepMutationHandler::fillPlaceholderWithResponse,
        failureConsumer = { placeholderIndex, throwable, message ->
            failureRecoveryHandler.handleActionFailure(placeholderIndex, throwable, message)
        }
    )
    private val contactLookupActionHandler = AgentStreamContactLookupActionHandler(
        runtime = AgentStreamContactLookupActionRuntime(
            stateProvider = { viewModel.internalUiState.value },
            sessionIdProvider = { viewModel.agentSessionId },
            userIdProvider = accountIdProvider
        ),
        callbacks = AgentStreamContactLookupActionCallbacks(
            clearWithoutPendingTool = contactSelectionStateHolder::clearLookupContactWithoutPendingTool,
            prepareSubmitting = contactSelectionStateHolder::prepareLookupContactResultSubmitting,
            appendAssistantPlaceholder = appendStreamingAssistantStep
        ),
        submitter = contactLookupResultSubmitter
    )
    private val deviceContactSelectionHandler = AgentStreamDeviceContactSelectionHandler(
        runtime = AgentStreamDeviceContactSelectionRuntime(
            stateProvider = { viewModel.internalUiState.value },
            sessionIdProvider = { viewModel.agentSessionId },
            isVoiceMode = isVoiceMode,
            scope = viewModel.viewModelScope,
            userIdProvider = accountIdProvider
        ),
        callbacks = AgentStreamDeviceContactSelectionCallbacks(
            clearWithoutPendingTool = contactSelectionStateHolder::clearDeviceContactsWithoutPendingTool,
            showSelection = contactSelectionStateHolder::showDeviceContactSelection,
            prepareSubmitting = contactSelectionStateHolder::prepareDeviceContactsResultSubmitting,
            appendUserStep = { text -> viewModel.appendClarificationStep(VoiceRole.User, text) },
            appendAssistantPlaceholder = appendStreamingAssistantStep,
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            startApiListening = { viewModel.startApiListening() }
        ),
        submitter = contactLookupResultSubmitter
    )

    private suspend fun handleActionCompletedWithoutTerminal(request: AgentStreamActionSubmitRequest) {
        if (request.actionId != ConfirmCallActionId) return
        if (!isActionSessionCurrent(request.sessionId)) {
            ignoreDetachedActionCallback(request.sessionId, request.placeholderIndex, "missing_terminal")
            return
        }
        AppFileLogger.i(
            "CALL_PAGE_DIAG",
            "confirm_call stream completed without terminal event sessionId=${request.sessionId} " +
                "placeholder=${request.placeholderIndex}"
        )
        stepMutationHandler.finalizeStep(request.placeholderIndex)
        releaseStreamOwnership(request.placeholderIndex)
        viewModel.syncConversationSnapshotForVoiceRecovery(
            request.sessionId,
            "confirm_call_completed_without_terminal"
        )
    }

    private fun isActionSessionCurrent(sessionId: String): Boolean =
        sessionId.trim().takeIf(String::isNotEmpty) ==
            viewModel.agentSessionId?.trim()?.takeIf(String::isNotEmpty)

    private fun ignoreDetachedActionCallback(sessionId: String, placeholderIndex: Int, callback: String) {
        releaseStreamOwnership(placeholderIndex)
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "AGENT_ACTION_CALLBACK_IGNORED",
                sessionId = sessionId,
                taskId = viewModel.internalUiState.value.taskId,
                result = "ignored",
                reason = "session_closed_or_switched",
                attributes = mapOf(
                    "callback" to callback,
                    "currentSessionId" to viewModel.agentSessionId.orEmpty(),
                    "placeholderIndex" to placeholderIndex.toString(),
                ),
            )
        )
    }

    fun cancelAutoConfirm() {
        confirmCallHandler.cancelAutoConfirm()
    }

    fun scheduleAutoAgentCallConfirm() {
        confirmCallHandler.scheduleAutoConfirm()
    }

    fun onAgentOptionSelect(optionId: String) {
        normalActionEntryHandler.onOptionSelect(optionId)
    }

    fun onAgentAnswerSubmit(answers: Map<String, Any>) {
        normalActionEntryHandler.onAnswerSubmit(answers)
    }

    fun onAgentPermissionResult(
        permissionKey: String,
        androidPermission: String?,
        status: String,
        granted: Boolean,
        message: String?
    ) {
        normalActionEntryHandler.onPermissionResult(
            permissionKey = permissionKey,
            androidPermission = androidPermission,
            status = status,
            granted = granted,
            message = message
        )
    }

    fun onAgentDocumentSubmit(result: DocumentParseResult) {
        normalActionEntryHandler.onDocumentSubmit(result)
    }

    fun onAgentLookupContactResult(payload: Map<String, Any?>) {
        contactLookupActionHandler.onResult(payload)
    }

    fun onAgentLookupDeviceContactsResolved(
        results: List<Map<String, Any?>>,
        echoText: String?,
        pendingSelection: DeviceContactSelectionUiState?
    ) {
        deviceContactSelectionHandler.onResolved(results, echoText, pendingSelection)
    }

    fun onAgentDeviceContactSelectionConfirm(
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>,
        echoSelection: Boolean
    ) {
        deviceContactSelectionHandler.onConfirm(selectedByName, echoSelection)
    }

    fun tryHandleAgentDeviceContactVoiceSelection(rawText: String): Boolean {
        return deviceContactSelectionHandler.tryHandleVoiceSelection(rawText)
    }

    fun onAgentDeviceContactSelectionCancel() {
        deviceContactSelectionHandler.onCancel()
    }

    fun onAgentCallConfirm(auto: Boolean) {
        confirmCallHandler.onConfirm(auto)
    }

    fun onAgentCallEdit() {
        confirmCallHandler.cancelAutoConfirm()
        viewModel.internalUiState.update {
            it.copy(
                agentCallSpec = null,
                stage = AssistantStage.Clarifying,
                status = "请输入要修改的内容"
            )
        }
    }

    private companion object {
        const val ConfirmCallActionId = "confirm_call"
    }
}
