package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class ContactSelectionStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {

    fun clearLookupContactWithoutPendingTool() {
        uiState.update {
            ContactSelectionStateReducer.clearLookupContactWithoutPendingTool(it)
        }
    }

    fun prepareLookupContactResultSubmitting(statusText: String) {
        uiState.update {
            ContactSelectionStateReducer.prepareLookupContactResultSubmitting(it, statusText)
        }
    }

    fun clearDeviceContactsWithoutPendingTool() {
        uiState.update {
            ContactSelectionStateReducer.clearDeviceContactsWithoutPendingTool(it)
        }
    }

    fun showDeviceContactSelection(
        selection: DeviceContactSelectionUiState,
        statusText: String
    ) {
        uiState.update {
            ContactSelectionStateReducer.showDeviceContactSelection(it, selection, statusText)
        }
    }

    fun prepareDeviceContactsResultSubmitting(statusText: String) {
        uiState.update {
            ContactSelectionStateReducer.prepareDeviceContactsResultSubmitting(it, statusText)
        }
    }
}
