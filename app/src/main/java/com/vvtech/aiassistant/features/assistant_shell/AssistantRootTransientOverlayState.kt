package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload

internal class AssistantRootTransientOverlayState(
    activeAgentPermissionRequestState: MutableState<PermissionRequestPayload?>,
    activeAgentDocumentRequestState: MutableState<DocumentImportRequestPayload?>,
    showVoiceModelSheetState: MutableState<Boolean>
) {
    var activeAgentPermissionRequest: PermissionRequestPayload? by activeAgentPermissionRequestState
        private set
    var activeAgentDocumentRequest: DocumentImportRequestPayload? by activeAgentDocumentRequestState
        private set
    var showVoiceModelSheet: Boolean by showVoiceModelSheetState
        private set

    fun updateActiveAgentPermissionRequest(request: PermissionRequestPayload?) {
        activeAgentPermissionRequest = request
    }

    fun consumeAgentPermissionRequest(fallback: PermissionRequestPayload?): PermissionRequestPayload? {
        val request = activeAgentPermissionRequest ?: fallback
        activeAgentPermissionRequest = null
        return request
    }

    fun updateActiveAgentDocumentRequest(request: DocumentImportRequestPayload?) {
        activeAgentDocumentRequest = request
    }

    fun clearAgentDocumentRequest() {
        activeAgentDocumentRequest = null
    }

    fun clearAgentRequests() {
        activeAgentPermissionRequest = null
        activeAgentDocumentRequest = null
    }

    fun setVoiceModelSheetVisible(visible: Boolean) {
        showVoiceModelSheet = visible
    }

    fun hideVoiceModelSheet() {
        showVoiceModelSheet = false
    }
}

@Composable
internal fun rememberAssistantRootTransientOverlayState(): AssistantRootTransientOverlayState {
    val activeAgentPermissionRequestState = remember {
        mutableStateOf<PermissionRequestPayload?>(null)
    }
    val activeAgentDocumentRequestState = remember {
        mutableStateOf<DocumentImportRequestPayload?>(null)
    }
    val showVoiceModelSheetState = rememberSaveable {
        mutableStateOf(false)
    }
    return remember(
        activeAgentPermissionRequestState,
        activeAgentDocumentRequestState,
        showVoiceModelSheetState
    ) {
        AssistantRootTransientOverlayState(
            activeAgentPermissionRequestState = activeAgentPermissionRequestState,
            activeAgentDocumentRequestState = activeAgentDocumentRequestState,
            showVoiceModelSheetState = showVoiceModelSheetState
        )
    }
}
