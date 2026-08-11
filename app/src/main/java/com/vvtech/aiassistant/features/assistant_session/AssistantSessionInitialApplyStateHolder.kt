package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class AssistantSessionInitialApplyStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {
    fun shouldPreserveTerminalResult(
        session: AssistantSessionResponse,
        pendingAiCallLaunch: Boolean
    ): Boolean {
        return AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult(
            session = session,
            state = uiState.value,
            pendingAiCallLaunch = pendingAiCallLaunch
        )
    }

    fun preserveTerminalResult(session: AssistantSessionResponse) {
        uiState.update { current ->
            AssistantSessionTerminalResultReducer.reduceTerminalResult(current, session)
        }
    }
}
