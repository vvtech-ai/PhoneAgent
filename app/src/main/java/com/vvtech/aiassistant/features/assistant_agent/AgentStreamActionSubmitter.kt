package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.AgentCommandIdentity
import com.vvtech.aiassistant.core.model.AgentCommandKind
import com.vvtech.aiassistant.features.assistant.viewmodel.runCatchingNonCancellation
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch

internal data class AgentStreamActionSubmitRequest(
    val sessionId: String,
    val actionId: String,
    val actionPayload: Map<String, Any>? = null,
    val contextReason: String,
    val logAction: String,
    val channel: String,
    val userId: String,
    val placeholderIndex: Int,
    val failureMessage: String,
    val languageCode: String,
    val responseLanguage: String,
    val identity: AgentCommandIdentity = AgentCommandIdentity.newIntent(
        sessionId,
        AgentCommandKind.Action,
    ),
)

internal class AgentStreamActionSubmitter(
    private val scope: CoroutineScope,
    private val streamUseCase: AgentStreamActionSubmitUseCase,
    private val userContextProvider: suspend (String) -> UserContextPayload,
    private val contextLogger: (action: String, sessionId: String, context: UserContextPayload) -> Unit,
    private val eventConsumer: (
        sessionId: String,
        placeholderIndex: Int,
        event: AgentStreamEvent
    ) -> Unit,
    private val failureConsumer: (
        sessionId: String,
        placeholderIndex: Int,
        throwable: Throwable,
        message: String,
        beforeRecover: (() -> Unit)?
    ) -> Unit,
    private val completedWithoutTerminalConsumer: suspend (AgentStreamActionSubmitRequest) -> Unit = {}
) {
    fun submit(
        request: AgentStreamActionSubmitRequest,
        onFailureBeforeHandle: ((Throwable) -> Unit)? = null,
        beforeRecover: (() -> Unit)? = null
    ): Job {
        return scope.launch {
            val startedAt = System.currentTimeMillis()
            logAction(request, "AGENT_ACTION_SUBMITTED", result = "started")
            runCatchingNonCancellation {
                val userContext = userContextProvider(request.contextReason)
                contextLogger(request.logAction, request.sessionId, userContext)
                var sawTerminalEvent = false
                streamUseCase.stream(request, userContext).catch { throw it }.collect { event ->
                    if (event.isTerminalForActionStream()) {
                        sawTerminalEvent = true
                        logAction(
                            request = request,
                            eventType = "AGENT_ACTION_TERMINAL_EVENT",
                            result = event.javaClass.simpleName,
                            elapsedMs = System.currentTimeMillis() - startedAt
                        )
                    }
                    eventConsumer(request.sessionId, request.placeholderIndex, event)
                }
                if (!sawTerminalEvent) {
                    logAction(
                        request = request,
                        eventType = "AGENT_ACTION_COMPLETED_WITHOUT_TERMINAL",
                        result = "missing_terminal",
                        reason = "stream_completed_without_terminal",
                        elapsedMs = System.currentTimeMillis() - startedAt
                    )
                    completedWithoutTerminalConsumer(request)
                } else {
                    logAction(
                        request = request,
                        eventType = "AGENT_ACTION_COMPLETED",
                        result = "terminal_received",
                        elapsedMs = System.currentTimeMillis() - startedAt
                    )
                }
            }.onFailure { throwable ->
                RuntimeStateLogger.error(
                    RuntimeStateLogEvent(
                        domain = RuntimeStateLogDomain.AGENT,
                        eventType = "AGENT_ACTION_FAILED",
                        traceId = request.identity.traceId,
                        commandId = request.identity.commandId,
                        sessionId = request.sessionId,
                        trigger = request.contextReason,
                        result = "failed",
                        reason = "action_stream_failure",
                        elapsedMs = System.currentTimeMillis() - startedAt,
                        attributes = mapOf(
                            "actionId" to request.actionId,
                            "channel" to request.channel,
                            "exceptionType" to throwable.javaClass.simpleName
                        )
                    ),
                    throwable
                )
                onFailureBeforeHandle?.invoke(throwable)
                failureConsumer(
                    request.sessionId,
                    request.placeholderIndex,
                    throwable,
                    request.failureMessage,
                    beforeRecover
                )
            }
        }
    }

    private fun logAction(
        request: AgentStreamActionSubmitRequest,
        eventType: String,
        result: String,
        reason: String? = null,
        elapsedMs: Long? = null
    ) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = eventType,
                traceId = request.identity.traceId,
                commandId = request.identity.commandId,
                sessionId = request.sessionId,
                trigger = request.contextReason,
                result = result,
                reason = reason,
                elapsedMs = elapsedMs,
                attributes = buildMap {
                    put("actionId", request.actionId)
                    put("channel", request.channel)
                    put("languageCode", request.languageCode)
                    put("responseLanguage", request.responseLanguage)
                    request.actionPayload?.let { payload ->
                        put("payloadKeys", payload.keys.sorted().joinToString(","))
                        put("payloadCallLanguage", payload["callLanguage"]?.toString().orEmpty())
                        put("payloadScriptLanguage", payload["scriptLanguage"]?.toString().orEmpty())
                        put("hasCallSpec", payload.containsKey("callSpec").toString())
                    }
                }
            )
        )
    }

    private fun AgentStreamEvent.isTerminalForActionStream(): Boolean =
        this is AgentStreamEvent.Signal ||
            this is AgentStreamEvent.Final ||
            this is AgentStreamEvent.Err
}
