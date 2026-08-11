package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload

internal const val AgentDocumentPickerUnavailableMessage = "未找到可用的系统文件选择器"

private val DefaultAgentDocumentPickerMimeTypes = listOf("text/plain", "text/markdown", "text/*")

internal class AssistantAgentDocumentPickerCallbacks(
    val onUpdateActiveAgentDocumentRequest: (DocumentImportRequestPayload) -> Unit,
    val onClearAgentDocumentRequest: () -> Unit,
    val onLaunchDocumentPicker: (Array<String>) -> Unit,
    val onAgentDocumentPickerCancelled: () -> Unit,
    val onShowMessage: (String) -> Unit
)

internal fun agentDocumentPickerMimeTypes(request: DocumentImportRequestPayload): List<String> {
    val accepted = request.acceptedMimeTypes
        .orEmpty()
        .map { it.trim() }
        .filter { it.isNotBlank() && it != "application/octet-stream" }
        .distinct()
    return accepted.ifEmpty { DefaultAgentDocumentPickerMimeTypes }
}

internal fun launchAssistantAgentDocumentPicker(
    request: DocumentImportRequestPayload?,
    callbacks: AssistantAgentDocumentPickerCallbacks
) {
    if (request == null) {
        return
    }
    callbacks.onUpdateActiveAgentDocumentRequest(request)
    val mimeTypes = agentDocumentPickerMimeTypes(request)
    runCatching {
        callbacks.onLaunchDocumentPicker(mimeTypes.toTypedArray())
    }.onFailure {
        callbacks.onClearAgentDocumentRequest()
        callbacks.onShowMessage(AgentDocumentPickerUnavailableMessage)
        callbacks.onAgentDocumentPickerCancelled()
    }
}

internal fun cancelAssistantAgentDocumentPicker(callbacks: AssistantAgentDocumentPickerCallbacks) {
    callbacks.onClearAgentDocumentRequest()
    callbacks.onAgentDocumentPickerCancelled()
}
