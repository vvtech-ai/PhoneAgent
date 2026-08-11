package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.viewmodel.runCatchingNonCancellation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

internal data class AgentContactLookupResultSubmitRequest(
    val sessionId: String,
    val pendingToolCallId: String,
    val userId: String,
    val result: Map<String, Any?>,
    val placeholderIndex: Int,
    val failureMessage: String
)

internal data class AgentDeviceContactsLookupResultSubmitRequest(
    val sessionId: String,
    val pendingToolCallId: String,
    val userId: String,
    val results: List<Map<String, Any?>>,
    val channel: String,
    val placeholderIndex: Int,
    val failureMessage: String
)

internal class AgentStreamContactLookupResultSubmitter(
    private val scope: CoroutineScope,
    private val lookupResultUseCase: AgentStreamContactLookupResultUseCase,
    private val responseConsumer: (placeholderIndex: Int, response: AgentChatResponse) -> Unit,
    private val failureConsumer: (placeholderIndex: Int, throwable: Throwable, message: String) -> Unit
) {
    fun submitContactLookupResult(request: AgentContactLookupResultSubmitRequest): Job {
        return scope.launch {
            runCatchingNonCancellation {
                lookupResultUseCase.submitContactLookupResult(request)
            }.onSuccess { response ->
                responseConsumer(request.placeholderIndex, response)
            }.onFailure { throwable ->
                failureConsumer(request.placeholderIndex, throwable, request.failureMessage)
            }
        }
    }

    fun submitDeviceContactsLookupResult(request: AgentDeviceContactsLookupResultSubmitRequest): Job {
        return scope.launch {
            runCatchingNonCancellation {
                lookupResultUseCase.submitDeviceContactsLookupResult(request)
            }.onSuccess { response ->
                responseConsumer(request.placeholderIndex, response)
            }.onFailure { throwable ->
                failureConsumer(request.placeholderIndex, throwable, request.failureMessage)
            }
        }
    }
}
