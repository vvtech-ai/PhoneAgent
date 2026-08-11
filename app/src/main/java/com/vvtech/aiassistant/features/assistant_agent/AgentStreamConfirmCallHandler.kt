package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.containsTransportNetworkError
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal data class AgentStreamConfirmCallRuntime(
    val stateProvider: () -> Index9AssistantUiState,
    val sessionIdProvider: () -> String?,
    val latestCallPageSeedProvider: () -> CallPageData,
    val isPendingLaunch: () -> Boolean,
    val setPendingLaunch: (Boolean) -> Unit,
    val isVoiceMode: () -> Boolean,
    val scope: CoroutineScope,
    val userIdProvider: () -> String
)

internal typealias AgentStreamConfirmCallSubmitAction = (
    AgentStreamActionSubmitRequest,
    ((Throwable) -> Unit)?,
    (() -> Unit)?
) -> Job

internal data class AgentStreamConfirmCallCallbacks(
    val setLatestCallPageSeed: (CallPageData) -> Unit,
    val appendUserStep: (String) -> Unit,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val logCallPage: (String) -> Unit,
    val audioGateSnapshot: () -> String,
    val suspendDialogAudioForCall: (String) -> Unit,
    val startCallSessionPolling: () -> Unit,
    val stopCallSessionPolling: () -> Unit,
    val appendAssistantPlaceholder: () -> Int,
    val submitAction: AgentStreamConfirmCallSubmitAction
)

internal class AgentStreamConfirmCallHandler(
    private val runtime: AgentStreamConfirmCallRuntime,
    private val callbacks: AgentStreamConfirmCallCallbacks
) {
    private var autoConfirmCallJob: Job? = null

    fun onConfirm(auto: Boolean = false) {
        val sessionId = runtime.sessionIdProvider() ?: return
        if (runtime.isPendingLaunch()) return
        cancelAutoConfirm()
        runtime.setPendingLaunch(true)
        val state = runtime.stateProvider()
        logCall(
            eventType = "CALL_CONFIRM_ACCEPTED",
            sessionId = sessionId,
            state = state,
            trigger = if (auto) "auto_confirm" else "user_confirm",
            result = "accepted"
        )
        callbacks.logCallPage(
            "onAgentCallConfirm auto=$auto sessionId=$sessionId beforeUpdate " +
                callbacks.audioGateSnapshot()
        )
        val launchPlan = AgentStreamConfirmCallLaunchPolicy.plan(
            AgentStreamConfirmCallLaunchInput(
                state = state,
                latestCallPageSeed = runtime.latestCallPageSeedProvider(),
                sessionId = sessionId,
                auto = auto,
                dialingStatusText = DialingStatusText,
                manualEchoText = ManualEchoText
            )
        )
        callbacks.setLatestCallPageSeed(launchPlan.callPageSeed)
        launchPlan.userEchoText?.let(callbacks.appendUserStep)
        callbacks.updateState { launchPlan.nextState }
        logCall(
            eventType = "CALL_PAGE_STATE_CHANGED",
            sessionId = sessionId,
            state = launchPlan.nextState,
            trigger = if (auto) "auto_confirm" else "user_confirm",
            stateBefore = state.showAiCallPage.toString(),
            stateAfter = launchPlan.nextState.showAiCallPage.toString(),
            result = "shown"
        )
        callbacks.logCallPage(
            "onAgentCallConfirm showAiCallPage=true sessionId=$sessionId afterUpdate " +
                callbacks.audioGateSnapshot()
        )
        callbacks.suspendDialogAudioForCall(SuspendReason)
        callbacks.startCallSessionPolling()
        logCall(
            eventType = "CALL_POLLING_STARTED",
            sessionId = sessionId,
            state = launchPlan.nextState,
            trigger = "confirm_call",
            result = "started"
        )
        val placeholderIndex = callbacks.appendAssistantPlaceholder()
        var keepCallPageOnFailure = false
        callbacks.submitAction(
            AgentStreamActionSubmitRequest(
                sessionId = sessionId,
                actionId = ConfirmCallActionId,
                contextReason = ContextReason,
                logAction = ConfirmCallActionId,
                channel = if (runtime.isVoiceMode()) "voice" else "text",
                userId = runtime.userIdProvider(),
                placeholderIndex = placeholderIndex,
                failureMessage = FailureMessage
            ),
            { throwable ->
                val failureState = runtime.stateProvider()
                val activeCallId = failureState.currentCallId?.isNotBlank() == true
                val structuredFailure = (throwable as? AgentStreamFailure)?.failure
                val isNetworkFailure = if (structuredFailure?.hasStructuredFailure == true) {
                    structuredFailure.isNetworkFailure
                } else {
                    containsTransportNetworkError(throwable.message)
                }
                val uncertainNetworkLaunch = isNetworkFailure &&
                    hasPendingOrVisibleCallContext(failureState)
                keepCallPageOnFailure = activeCallId || uncertainNetworkLaunch
                if (!keepCallPageOnFailure) {
                    runtime.setPendingLaunch(false)
                    callbacks.stopCallSessionPolling()
                }
                RuntimeStateLogger.error(
                    RuntimeStateLogEvent(
                        domain = RuntimeStateLogDomain.CALL,
                        eventType = "CALL_CONFIRM_ACTION_FAILED",
                        sessionId = sessionId,
                        taskId = runtime.stateProvider().taskId,
                        callId = runtime.stateProvider().currentCallId,
                        trigger = if (auto) "auto_confirm" else "user_confirm",
                        result = "failed",
                        reason = when {
                            activeCallId -> "active_call_result_pending"
                            uncertainNetworkLaunch -> "network_failure_call_launch_uncertain"
                            else -> "confirm_action_failure"
                        },
                        attributes = mapOf(
                            "exceptionType" to throwable.javaClass.simpleName,
                            "activeCallId" to activeCallId.toString(),
                            "keepCallPage" to keepCallPageOnFailure.toString()
                        )
                    ),
                    throwable
                )
                callbacks.logCallPage(
                    "onAgentCallConfirm failed sessionId=$sessionId keepCallPage=$keepCallPageOnFailure " +
                        "message=${throwable.message} " +
                        callbacks.audioGateSnapshot()
                )
            },
            {
                if (!keepCallPageOnFailure) {
                    callbacks.updateState {
                        it.copy(
                            showAiCallPage = false,
                            handoffInFlight = false
                        )
                    }
                }
            }
        )
    }

    fun scheduleAutoConfirm() {
        cancelAutoConfirm()
        autoConfirmCallJob = runtime.scope.launch {
            delay(AutoConfirmDelayMs)
            val state = runtime.stateProvider()
            if (state.agentCallSpec != null &&
                !state.processingTurn &&
                !state.showAiCallPage &&
                !runtime.isPendingLaunch()
            ) {
                onConfirm(auto = true)
            }
        }
    }

    fun cancelAutoConfirm() {
        autoConfirmCallJob?.cancel()
        autoConfirmCallJob = null
    }

    private companion object {
        private const val AutoConfirmDelayMs = 1500L
        private const val ConfirmCallActionId = "confirm_call"
        private const val ContextReason = "agent_confirm_call"
        private const val DialingStatusText = "正在拨打电话..."
        private const val ManualEchoText = "已确认拨打"
        private const val FailureMessage = "拨打失败"
        private const val SuspendReason = "agent_call_confirm"
    }

    private fun hasPendingOrVisibleCallContext(state: Index9AssistantUiState): Boolean {
        return state.showAiCallPage ||
            runtime.isPendingLaunch()
    }

    private fun logCall(
        eventType: String,
        sessionId: String,
        state: Index9AssistantUiState,
        trigger: String,
        result: String,
        stateBefore: String? = null,
        stateAfter: String? = null
    ) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = eventType,
                sessionId = sessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                trigger = trigger,
                stateBefore = stateBefore,
                stateAfter = stateAfter,
                result = result,
                attributes = mapOf(
                    "voiceMode" to runtime.isVoiceMode().toString(),
                    "pendingLaunch" to runtime.isPendingLaunch().toString()
                )
            )
        )
    }
}
