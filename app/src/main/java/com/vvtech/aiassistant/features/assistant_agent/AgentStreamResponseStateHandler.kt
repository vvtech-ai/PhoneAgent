package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.localizedVoiceRecoveryResumeStatus
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingError
import com.vvtech.aiassistant.features.assistant.voiceRecoveryDecision
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalPolicy
import com.vvtech.aiassistant.features.assistant_voice.VoiceListenTriggers
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal data class AgentStreamResponseRuntimeCallbacks(
    val stateProvider: () -> Index9AssistantUiState,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val latestCallPageSeedProvider: () -> CallPageData,
    val setLatestCallPageSeed: (CallPageData) -> Unit,
    val scheduleAutoAgentCallConfirm: () -> Unit,
    val internalLog: (String) -> Unit,
    val markTaskErrorRecoveryConfirmed: (reason: String, promoteToRunning: Boolean) -> Unit
)

internal data class AgentStreamResponseVoiceCallbacks(
    val isVoiceMode: () -> Boolean,
    val currentVoiceLanguage: () -> VoiceLanguage,
    val maybeTtsFlush: () -> Unit,
    val maybeTtsSignal: (String) -> Unit,
    val appendAssistantStep: (String) -> Unit,
    val markTaskErrorRecoveryInProgress: (String) -> Unit,
    val resumeListeningAfterAgentRecovery: (String) -> Unit
)

internal data class AgentStreamApplyCallResultLogInput(
    val responseSessionId: String,
    val currentSessionId: String?,
    val callResult: CallResultPayload?,
    val resolvedConversationStatus: String,
    val resultStatusText: String
)

internal data class AgentStreamResponseTerminalCallbacks(
    val agentSessionIdProvider: () -> String?,
    val callResultStatusText: (CallResultPayload?, String?) -> String,
    val callResultTaskStatus: (CallResultPayload?) -> String,
    val logApplyCallResult: (AgentStreamApplyCallResultLogInput) -> Unit,
    val currentBatchIdProvider: () -> String = { "" },
    val clearActiveBatchCallState: () -> Unit,
    val terminalSideEffectHandler: AgentStreamTerminalSideEffectHandler,
    val onTaskResultApplied: (AgentChatResponse) -> Unit = {},
)

internal class AgentStreamResponseStateHandler(
    private val runtime: AgentStreamResponseRuntimeCallbacks,
    private val voice: AgentStreamResponseVoiceCallbacks,
    private val terminal: AgentStreamResponseTerminalCallbacks
) {
    fun apply(response: AgentChatResponse) {
        logResponse(
            eventType = "AGENT_RESPONSE_RECEIVED",
            response = response,
            result = response.type
        )
        confirmTaskErrorRecovery(response)
        val text = response.text?.trim()
        when (response.type) {
            TYPE_TEXT_REPLY -> applyTextReply()
            TYPE_ASK_USER,
            TYPE_SHOW_OPTIONS,
            TYPE_REQUEST_PERMISSION,
            TYPE_IMPORT_DOCUMENT_REQUEST -> applyInteractiveResponseState(response)
            TYPE_LOOKUP_CONTACT_REQUEST -> {
                runtime.updateState {
                    AgentStreamLookupRequestStateReducer.contactLookupRequest(it, response)
                }
            }
            TYPE_LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST -> {
                val nextState = AgentStreamLookupRequestStateReducer.deviceContactsLookupRequest(
                    state = runtime.stateProvider(),
                    response = response
                ) ?: return
                runtime.updateState { nextState }
            }
            TYPE_MAKE_CALL_REQUEST -> applyMakeCallRequest(response)
            TYPE_CALL_RESULT -> applyCallResult(response)
            TYPE_BATCH_CALL_RESULT -> applyBatchCallResult(response)
            TYPE_ERROR -> applyError(response, text)
            else -> applyUnknown(response)
        }
    }

    private fun confirmTaskErrorRecovery(response: AgentChatResponse) {
        when (AgentStreamSimpleResponseStatePolicy.recoveryConfirmation(response.type)) {
            AgentStreamRecoveryConfirmation.PromoteRunning -> {
                runtime.markTaskErrorRecoveryConfirmed("agent_response_${response.type}", true)
            }
            AgentStreamRecoveryConfirmation.TerminalNoPromote -> {
                runtime.markTaskErrorRecoveryConfirmed("agent_response_${response.type}", false)
            }
            AgentStreamRecoveryConfirmation.None -> Unit
        }
    }

    private fun applyTextReply() {
        voice.maybeTtsFlush()
        runtime.updateState {
            AgentStreamSimpleResponseStatePolicy.textReply(it, currentAppText("AI已回复", "AI replied"))
        }
    }

    private fun applyInteractiveResponseState(response: AgentChatResponse) {
        val plan = AgentStreamInteractiveResponsePolicy.plan(
            state = runtime.stateProvider(),
            response = response,
            voiceMode = voice.isVoiceMode(),
            voiceLanguage = voice.currentVoiceLanguage()
        ) ?: return
        plan.voicePrompt?.let(voice.maybeTtsSignal)
        runtime.updateState { plan.nextState }
    }

    private fun applyMakeCallRequest(response: AgentChatResponse) {
        val plan = AgentStreamMakeCallRequestPolicy.plan(
            state = runtime.stateProvider(),
            currentCallPageSeed = runtime.latestCallPageSeedProvider(),
            response = response
        )
        plan.nextCallPageSeed?.let(runtime.setLatestCallPageSeed)
        runtime.updateState { plan.nextState }
        runtime.scheduleAutoAgentCallConfirm()
    }

    private fun applyCallResult(response: AgentChatResponse) {
        val callResult = response.callResult
        val currentUiState = runtime.stateProvider()
        val resultStatusText = terminal.callResultStatusText(callResult, currentUiState.sceneType)
        val resolvedConversationStatus = terminal.callResultTaskStatus(callResult)
        val currentSessionId = terminal.agentSessionIdProvider()
        terminal.logApplyCallResult(
            AgentStreamApplyCallResultLogInput(
                responseSessionId = response.sessionId,
                currentSessionId = currentSessionId,
                callResult = callResult,
                resolvedConversationStatus = resolvedConversationStatus,
                resultStatusText = resultStatusText
            )
        )
        logResponse(
            eventType = "CALL_RESULT_APPLIED",
            response = response,
            result = callResult?.status ?: "missing_payload",
            reason = "agent_call_result",
            callAttemptId = callResult?.metadata?.get("callAttemptId"),
            callId = callResult?.metadata?.get("callId")
        )
        val terminalPlan = AgentStreamTerminalResponsePolicy.callResult(
            AgentStreamTerminalResponseInput(
                state = currentUiState,
                response = response,
                statusText = resultStatusText,
                conversationStatus = resolvedConversationStatus,
                conversationSessionId = currentSessionId
            )
        )
        terminal.terminalSideEffectHandler.apply(
            AgentStreamTerminalSideEffectInput(
                plan = terminalPlan,
                clearPrimarySummaryAction = true
            )
        )
        terminal.onTaskResultApplied(response)
    }

    private fun applyBatchCallResult(response: AgentChatResponse) {
        val activeBatchId = terminal.currentBatchIdProvider().trim().takeIf(String::isNotBlank)
        terminal.clearActiveBatchCallState()
        val result = response.batchCallResult
        val resolvedConversationStatus = TaskBatchCallFinalPolicy.resolvedConversationStatus(result)
        val currentSessionId = terminal.agentSessionIdProvider() ?: response.sessionId
        val statusText = TaskBatchCallFinalPolicy.statusText(result, resolvedConversationStatus)
        val terminalPlan = AgentStreamTerminalResponsePolicy.batchCallResult(
            AgentStreamTerminalResponseInput(
                state = runtime.stateProvider(),
                response = response,
                statusText = statusText,
                conversationStatus = resolvedConversationStatus,
                conversationSessionId = currentSessionId
            ),
            batchAttemptId = activeBatchId,
        )
        terminal.terminalSideEffectHandler.apply(
            AgentStreamTerminalSideEffectInput(
                plan = terminalPlan,
                clearPrimarySummaryAction = false
            )
        )
        terminal.onTaskResultApplied(response)
    }

    private fun applyError(response: AgentChatResponse, text: String?) {
        val safeText = sanitizeUserFacingError(
            text,
            voice.currentVoiceLanguage(),
            currentAppText("系统异常，请重试", "System error. Please try again.")
        )
        if (voice.isVoiceMode()) {
            val language = voice.currentVoiceLanguage()
            voice.markTaskErrorRecoveryInProgress("EXECUTION_ERROR")
            runtime.updateState {
                AgentStreamSimpleResponseStatePolicy.voiceRecovery(
                    state = it,
                    statusText = voiceRecoveryDecision(
                        text,
                        language,
                        localizedVoiceRecoveryResumeStatus(language)
                    ).status,
                    clearDocumentImporting = true
                )
            }
            logVoiceRecovery(
                response = response,
                trigger = VoiceListenTriggers.AgentErrorRecovery,
                reason = "agent_error_response"
            )
            voice.resumeListeningAfterAgentRecovery(VoiceListenTriggers.AgentErrorRecovery)
        } else {
            runtime.updateState {
                AgentStreamSimpleResponseStatePolicy.executionError(
                    state = it,
                    errorText = safeText,
                    statusText = currentAppText("出错了", "Something went wrong"),
                    clearDocumentImporting = true
                )
            }
        }
    }

    private fun applyUnknown(response: AgentChatResponse) {
        runtime.internalLog("handleAgentResponse unknown type=${response.type}")
        if (voice.isVoiceMode()) {
            val language = voice.currentVoiceLanguage()
            voice.markTaskErrorRecoveryInProgress("EXECUTION_ERROR")
            runtime.updateState {
                AgentStreamSimpleResponseStatePolicy.voiceRecovery(
                    state = it,
                    statusText = localizedVoiceRecoveryResumeStatus(language),
                    clearDocumentImporting = true
                )
            }
            logVoiceRecovery(
                response = response,
                trigger = VoiceListenTriggers.AgentUnknownResponseRecovery,
                reason = "agent_unknown_response"
            )
            voice.resumeListeningAfterAgentRecovery(VoiceListenTriggers.AgentUnknownResponseRecovery)
        } else {
            runtime.updateState {
                AgentStreamSimpleResponseStatePolicy.executionError(
                    state = it,
                    errorText = AgentStreamSimpleResponseStatePolicy.unknownErrorText(response.type),
                    statusText = currentAppText("出错了", "Something went wrong"),
                    clearDocumentImporting = true
                )
            }
        }
    }

    private fun logVoiceRecovery(
        response: AgentChatResponse,
        trigger: String,
        reason: String
    ) {
        val state = runtime.stateProvider()
        RuntimeStateLogger.warn(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "AGENT_ERROR_RECOVERY",
                sessionId = response.sessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                trigger = trigger,
                result = "voice_resume_requested",
                reason = reason,
                attributes = mapOf(
                    "responseType" to response.type,
                    "callOutcomePending" to isAwaitingCallOutcome(state).toString(),
                    "showAiCallPage" to state.showAiCallPage.toString()
                )
            )
        )
    }

    private fun logResponse(
        eventType: String,
        response: AgentChatResponse,
        result: String,
        reason: String? = null,
        callAttemptId: String? = null,
        callId: String? = null
    ) {
        val state = runtime.stateProvider()
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = eventType,
                sessionId = response.sessionId,
                taskId = state.taskId,
                callAttemptId = callAttemptId,
                callId = callId ?: state.currentCallId,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "responseType" to response.type,
                    "voiceMode" to voice.isVoiceMode().toString(),
                    "callOutcomePending" to isAwaitingCallOutcome(state).toString()
                )
            )
        )
    }

    private fun isAwaitingCallOutcome(state: Index9AssistantUiState): Boolean =
        state.processingTurn &&
            (isCallOutcomePendingStatusText(state.status) ||
                isCallOutcomePendingStatusText(state.callPageData.status))

    private companion object {
        const val TYPE_TEXT_REPLY = "TEXT_REPLY"
        const val TYPE_ASK_USER = "ASK_USER"
        const val TYPE_SHOW_OPTIONS = "SHOW_OPTIONS"
        const val TYPE_REQUEST_PERMISSION = "REQUEST_PERMISSION"
        const val TYPE_IMPORT_DOCUMENT_REQUEST = "IMPORT_DOCUMENT_REQUEST"
        const val TYPE_LOOKUP_CONTACT_REQUEST = "LOOKUP_CONTACT_REQUEST"
        const val TYPE_LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST"
        const val TYPE_MAKE_CALL_REQUEST = "MAKE_CALL_REQUEST"
        const val TYPE_CALL_RESULT = "CALL_RESULT"
        const val TYPE_BATCH_CALL_RESULT = "BATCH_CALL_RESULT"
        const val TYPE_ERROR = "ERROR"
    }
}
