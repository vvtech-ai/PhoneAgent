package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.data.repository.AssistantRepository

internal class AssistantSessionDetailPromptUseCase(
    private val repository: AssistantRepository
) {
    suspend fun loadPrompts(
        sceneType: String,
        fallbackTitle: String,
        fallbackIntro: String
    ): DetailSupplementPromptResponse {
        return runCatching {
            repository.loadDetailSupplementPrompts(sceneType)
        }.getOrElse {
            DetailSupplementPromptResponse(
                sceneType = sceneType,
                title = fallbackTitle,
                intro = fallbackIntro,
                questions = emptyList()
            )
        }
    }
}
