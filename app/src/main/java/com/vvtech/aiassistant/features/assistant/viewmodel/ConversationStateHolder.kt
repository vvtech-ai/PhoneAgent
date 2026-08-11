package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class ConversationStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {

    fun prepareTextTurnSubmitting(
        clearCallResult: Boolean,
        statusText: String
    ) {
        uiState.update {
            ConversationStateReducer.prepareTextTurnSubmitting(
                state = it,
                clearCallResult = clearCallResult,
                statusText = statusText
            )
        }
    }

    fun prepareVoiceSupplementSubmitting(
        clearCallResult: Boolean,
        statusText: String
    ) {
        uiState.update {
            ConversationStateReducer.prepareVoiceSupplementSubmitting(
                state = it,
                clearCallResult = clearCallResult,
                statusText = statusText
            )
        }
    }
}
