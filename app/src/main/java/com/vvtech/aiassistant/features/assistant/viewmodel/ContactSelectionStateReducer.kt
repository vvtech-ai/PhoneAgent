package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object ContactSelectionStateReducer {

    fun clearLookupContactWithoutPendingTool(
        state: Index9AssistantUiState
    ): Index9AssistantUiState {
        return state.copy(
            agentLookupContactPhone = null,
            agentLookupContactInFlight = false,
            processingTurn = false
        )
    }

    fun prepareLookupContactResultSubmitting(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentPendingToolCallId = null,
            agentLookupContactPhone = null,
            agentLookupContactInFlight = false,
            status = statusText
        )
    }

    fun clearDeviceContactsWithoutPendingTool(
        state: Index9AssistantUiState
    ): Index9AssistantUiState {
        return state.copy(
            agentLookupDeviceContactsRequest = null,
            agentLookupDeviceContactsInFlight = false,
            agentDeviceContactSelection = null,
            processingTurn = false
        )
    }

    fun showDeviceContactSelection(
        state: Index9AssistantUiState,
        selection: DeviceContactSelectionUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = false,
            error = null,
            agentLookupDeviceContactsInFlight = false,
            agentDeviceContactSelection = selection,
            status = statusText
        )
    }

    fun prepareDeviceContactsResultSubmitting(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentPendingToolCallId = null,
            agentLookupDeviceContactsRequest = null,
            agentLookupDeviceContactsInFlight = false,
            agentDeviceContactSelection = null,
            status = statusText
        )
    }
}
