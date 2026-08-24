package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.containsTransportNetworkError
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
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
    val userIdProvider: () -> String,
    val languageCodeProvider: () -> String,
    val responseLanguageProvider: () -> String
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
                dialingStatusText = dialingStatusText(),
                manualEchoText = manualEchoText()
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
                actionPayload = confirmCallActionPayload(
                    languageCode = runtime.languageCodeProvider(),
                    callSpec = state.agentCallSpec
                ),
                contextReason = ContextReason,
                logAction = ConfirmCallActionId,
                channel = if (runtime.isVoiceMode()) "voice" else "text",
                userId = runtime.userIdProvider(),
                placeholderIndex = placeholderIndex,
                failureMessage = failureMessage(),
                languageCode = runtime.languageCodeProvider(),
                responseLanguage = runtime.responseLanguageProvider()
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
        private const val SuspendReason = "agent_call_confirm"
    }

    private fun dialingStatusText(): String =
        currentAppText("正在拨打电话...", "Calling...")

    private fun manualEchoText(): String =
        currentAppText("已确认拨打", "Call confirmed")

    private fun failureMessage(): String =
        currentAppText("拨打失败", "Call failed")

    private fun confirmCallActionPayload(
        languageCode: String,
        callSpec: CallSpecPayload?
    ): Map<String, Any>? {
        if (!languageCode.startsWith("en", ignoreCase = true)) return null
        val callSpecPayload = callSpec?.let { englishCallSpecPayload(it, languageCode) }
        return buildMap {
            put("languageCode", languageCode)
            put("responseLanguage", "English")
            put("callLanguage", "en-US")
            put("calleeLanguage", "en-US")
            put("spokenLanguage", "en-US")
            put("scriptLanguage", "English")
            put("displayLanguage", "English")
            put("callInstruction", englishOutboundCallInstruction())
            put(
                "instructions",
                listOf(
                    "Conduct the outbound phone call in English only.",
                    "Every AI spoken line to the callee must be English.",
                    "Every call transcript, status, tool result, summary, and receipt field must be displayed in English.",
                    "Do not output Chinese or pinyin-style fake English.",
                    "If the callee replies in Chinese, understand it internally and continue responding in English.",
                    "Preserve real phone numbers and addresses. Use an English alias for Chinese business names when obvious."
                )
            )
            if (callSpecPayload != null) {
                put("callSpec", callSpecPayload)
                put("call_spec", callSpecPayload)
                put("makeCall", callSpecPayload)
                put("make_call", callSpecPayload)
            }
        }
    }

    private fun englishCallSpecPayload(
        spec: CallSpecPayload,
        languageCode: String
    ): Map<String, Any> {
        val targetName = englishDisplayText(spec.targetName)
        val primaryGoal = englishDisplayText(spec.primaryGoal)
        val summaryLines = spec.summaryLines.map(::englishDisplayText)
        val rules = englishCallRules(spec.negotiationRules)
        val boundaries = englishCallBoundaries(spec.boundaries)
        return buildMap {
            put("phoneNumber", spec.phoneNumber)
            put("scene", spec.scene)
            put("targetName", targetName)
            put("primaryGoal", primaryGoal)
            put("summaryLines", summaryLines)
            put("negotiationRules", rules)
            put("boundaries", boundaries)
            put("languageCode", languageCode)
            put("responseLanguage", "English")
            put("callLanguage", "en-US")
            put("spokenLanguage", "en-US")
            put("scriptLanguage", "English")
            put("openingText", "Hello, is this $targetName?")
            put(
                "successCriteria",
                listOf(
                    "Confirm the reservation or call task result in English.",
                    "Return the result summary and receipt fields in English.",
                    "Keep real phone numbers and addresses unchanged."
                )
            )
            put("callInstruction", englishOutboundCallInstruction())
        }
    }

    private fun englishCallRules(existing: List<String>?): List<String> =
        mergeEnglishCallGuidance(
            existing,
            listOf(
                "Speak to the callee in English only.",
                "Ask every question and confirmation in English.",
                "If the callee answers in Chinese, infer the meaning internally and answer back in English.",
                "Do not use Chinese words, Chinese numerals, or pinyin-style fake English in the call script."
            )
        )

    private fun englishCallBoundaries(existing: List<String>?): List<String> =
        mergeEnglishCallGuidance(
            existing,
            listOf(
                "English-only outbound call.",
                "English-only transcript and result display.",
                "No Chinese fallback for restaurant booking details.",
                "No pinyin conversion as a substitute for English translation."
            )
        )

    private fun mergeEnglishCallGuidance(
        existing: List<String>?,
        required: List<String>
    ): List<String> {
        val merged = existing.orEmpty()
            .map(::englishDisplayText)
            .filter { it.isNotBlank() }
            .toMutableList()
        required.forEach { rule ->
            if (merged.none { it.equals(rule, ignoreCase = true) }) merged += rule
        }
        return merged
    }

    private fun englishDisplayText(raw: String): String =
        sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)

    private fun englishOutboundCallInstruction(): String =
        "Conduct the outbound phone conversation in English only. " +
            "The AI must speak English to the callee even when the callee, restaurant, address, " +
            "phone number, or local business data is Chinese. " +
            "Translate callee replies internally and continue in English. " +
            "Write call scripts, spoken prompts, status text, tool results, summaries, receipt fields, " +
            "and transcripts in English. " +
            "Do not output Chinese, Chinese numerals, or pinyin-style fake English such as " +
            "'yu ding jiao ben yi sheng cheng' or 'zheng zai bo da dian hua'. " +
            "Use English words for phone endings, party size, time, private room, booking status, " +
            "and confirmation messages. Preserve phone numbers and addresses as data."

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
