package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.data.translation.TranslationCallSettingsRepository
import com.vvtech.aiassistant.domain.translation.TranslationCallPlanResult
import com.vvtech.aiassistant.domain.translation.TranslationCallPreferences
import com.vvtech.aiassistant.domain.translation.TranslationCallRoutePolicy
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.features.assistant_calls.doubaoTranslationLanguagePairRejectMessage

data class TranslationCallLaunchInput(
    val rawNumber: String,
    val displayName: String = "",
    val defaultCountryDialCode: String,
    val countryIso: String = "",
    val myLanguage: String,
    val peerLanguage: String,
    val domesticSipAccountId: String,
    val internationalSipAccountId: String
)

sealed interface TranslationCallLaunchResult {
    object Started : TranslationCallLaunchResult
    data class Rejected(val message: String) : TranslationCallLaunchResult
}

class TranslationCallLauncher(
    private val coordinator: TranslationCallCoordinator,
    private val regionRepository: TranslationRegionRepository,
    private val settingsRepository: TranslationCallSettingsRepository
) {
    fun start(input: TranslationCallLaunchInput): TranslationCallLaunchResult {
        val settings = settingsRepository.state.value
        return when (
            val plan = TranslationCallRoutePolicy.plan(
                region = regionRepository.state.value,
                rawNumber = input.rawNumber,
                defaultCountryDialCode = input.defaultCountryDialCode,
                countryIso = input.countryIso,
                preferences = TranslationCallPreferences(
                    domesticProvider = settings.domesticProvider,
                    overseasProvider = settings.overseasProvider,
                    domesticSipAccountId = input.domesticSipAccountId,
                    internationalSipAccountId = input.internationalSipAccountId,
                    serviceRegion = settings.serviceRegion
                )
            )
        ) {
            is TranslationCallPlanResult.Failed ->
                TranslationCallLaunchResult.Rejected(plan.detail)
            is TranslationCallPlanResult.Ready -> {
                if (plan.plan.provider == TranslationRealtimeProvider.Doubao) {
                    doubaoTranslationLanguagePairRejectMessage(
                        callerLanguageCode = input.myLanguage,
                        calleeLanguageCode = input.peerLanguage
                    )?.let { message ->
                        return TranslationCallLaunchResult.Rejected(message)
                    }
                }
                if (
                    coordinator.start(
                        plan.plan,
                        input.myLanguage,
                        input.peerLanguage,
                        input.displayName,
                        input.countryIso,
                        playOriginalAudio = settings.playOriginalAudio,
                        originalAudioGainPercent = settings.originalAudioGainPercent,
                        originalAudioVolumePercent = settings.originalAudioVolumePercent
                    )
                ) {
                    TranslationCallLaunchResult.Started
                } else {
                    TranslationCallLaunchResult.Rejected("已有实时翻译通话正在进行")
                }
            }
        }
    }
}
