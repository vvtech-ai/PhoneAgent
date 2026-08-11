package com.vvtech.aiassistant.features.translation_call.state

import android.content.Context
import com.vvtech.aiassistant.AIAssistantApplication
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import kotlinx.coroutines.flow.StateFlow

class TranslationRegionStateHolder internal constructor(
    private val repository: TranslationRegionRepository
) {
    val state: StateFlow<TranslationRegionState> = repository.state

    suspend fun refresh(): TranslationRegionState = repository.refresh()

    companion object {
        fun from(context: Context): TranslationRegionStateHolder {
            val application = context.applicationContext as? AIAssistantApplication
                ?: error("AIAssistantApplication is required")
            return TranslationRegionStateHolder(application.translationRegionRepository)
        }
    }
}
