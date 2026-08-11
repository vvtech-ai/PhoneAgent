package com.vvtech.aiassistant.features.translation_call.state

import android.content.Context
import com.vvtech.aiassistant.AIAssistantApplication
import com.vvtech.aiassistant.data.translation.TranslationCallSettingsRepository
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsVisibility
import kotlinx.coroutines.flow.StateFlow

class TranslationCallSettingsStateHolder internal constructor(
    private val regionRepository: TranslationRegionRepository,
    private val settingsRepository: TranslationCallSettingsRepository
) {
    val region: StateFlow<TranslationRegionState> = regionRepository.state
    val settings: StateFlow<TranslationCallSettings> = settingsRepository.state

    fun visibility(): TranslationCallSettingsVisibility =
        TranslationCallSettingsPolicy.visibility(region.value)

    fun selectDomesticProvider(provider: TranslationRealtimeProvider) {
        settingsRepository.selectDomesticProvider(provider)
    }

    fun selectOverseasProvider(provider: TranslationRealtimeProvider) {
        settingsRepository.selectOverseasProvider(provider)
    }

    fun selectServiceRegion(region: TranslationServiceRegion) {
        settingsRepository.selectServiceRegion(region)
    }

    fun setPlayOriginalAudio(enabled: Boolean) {
        settingsRepository.setPlayOriginalAudio(enabled)
    }

    fun setOriginalAudioGainPercent(percent: Int) {
        settingsRepository.setOriginalAudioGainPercent(percent)
    }

    fun setOriginalAudioVolumePercent(percent: Int) {
        settingsRepository.setOriginalAudioVolumePercent(percent)
    }

    companion object {
        fun from(context: Context): TranslationCallSettingsStateHolder {
            val application = context.applicationContext as? AIAssistantApplication
                ?: error("AIAssistantApplication is required")
            return TranslationCallSettingsStateHolder(
                regionRepository = application.translationRegionRepository,
                settingsRepository = application.translationCallSettingsRepository
            )
        }
    }
}
