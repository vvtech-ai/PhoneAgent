package com.vvtech.aiassistant.features.translation_call.model

import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import java.util.Locale

data class TranslationCallSettings(
    val domesticProvider: TranslationRealtimeProvider = TranslationRealtimeProvider.Qwen,
    val overseasProvider: TranslationRealtimeProvider = TranslationRealtimeProvider.Gemini,
    val serviceRegion: TranslationServiceRegion = TranslationServiceRegion.Default,
    val playOriginalAudio: Boolean = false,
    val originalAudioGainPercent: Int = TranslationCallSettingsPolicy.DefaultOriginalAudioGainPercent,
    val originalAudioVolumePercent: Int =
        TranslationCallSettingsPolicy.DefaultOriginalAudioVolumePercent
)

data class TranslationCallSettingsVisibility(
    val showDomesticProvider: Boolean,
    val showOverseasProvider: Boolean,
    val showSipAccounts: Boolean,
    val showServiceRegion: Boolean,
    val locationMessage: String?
)

object TranslationCallSettingsPolicy {
    const val DefaultOriginalAudioGainPercent = 50
    const val DefaultOriginalAudioVolumePercent = 100
    val originalAudioGainPercentOptions = (0..50 step 10).toList()
    val originalAudioVolumePercentOptions = (0..100 step 10).toList()
    val domesticProviders = listOf(
        TranslationRealtimeProvider.Qwen,
        TranslationRealtimeProvider.Doubao
    )
    val overseasProviders = listOf(
        TranslationRealtimeProvider.OpenAi,
        TranslationRealtimeProvider.Gemini
    )
    val serviceRegions = listOf(
        TranslationServiceRegion.Default,
        TranslationServiceRegion.UnitedStates,
        TranslationServiceRegion.Japan
    )

    fun visibility(region: TranslationRegionState): TranslationCallSettingsVisibility {
        return when (region) {
            is TranslationRegionState.Resolved -> if (region.isChina) {
                TranslationCallSettingsVisibility(
                    showDomesticProvider = true,
                    showOverseasProvider = false,
                    showSipAccounts = true,
                    showServiceRegion = false,
                    locationMessage = null
                )
            } else {
                TranslationCallSettingsVisibility(
                    showDomesticProvider = false,
                    showOverseasProvider = true,
                    showSipAccounts = false,
                    showServiceRegion = true,
                    locationMessage = null
                )
            }
            TranslationRegionState.Resolving -> hidden("正在确认所在地区…")
            is TranslationRegionState.Unavailable -> hidden(region.reason)
        }
    }

    fun domesticProvider(raw: String?): TranslationRealtimeProvider = when (
        raw.normalized()
    ) {
        "DOUBAO" -> TranslationRealtimeProvider.Doubao
        else -> TranslationRealtimeProvider.Qwen
    }

    fun overseasProvider(raw: String?): TranslationRealtimeProvider = when (
        raw.normalized()
    ) {
        "OPENAI", "OPEN_AI" -> TranslationRealtimeProvider.OpenAi
        else -> TranslationRealtimeProvider.Gemini
    }

    fun serviceRegion(raw: String?): TranslationServiceRegion = when (
        raw.normalized()
    ) {
        "US", "UNITEDSTATES", "UNITED_STATES" -> TranslationServiceRegion.UnitedStates
        "JP", "JAPAN" -> TranslationServiceRegion.Japan
        else -> TranslationServiceRegion.Default
    }

    fun originalAudioGainPercent(raw: Int): Int =
        ((raw.coerceIn(0, 50) + 5) / 10) * 10

    fun originalAudioVolumePercent(raw: Int): Int =
        ((raw.coerceIn(0, 100) + 5) / 10) * 10

    private fun hidden(message: String) = TranslationCallSettingsVisibility(
        showDomesticProvider = false,
        showOverseasProvider = false,
        showSipAccounts = false,
        showServiceRegion = false,
        locationMessage = message
    )

    private fun String?.normalized(): String =
        this?.trim()?.uppercase(Locale.ROOT).orEmpty()
}

data class TranslationServiceEndpointSelection(
    val baseUrl: String,
    val region: TranslationServiceRegion
)

class TranslationServiceEndpointResolver(
    defaultBaseUrl: String,
    unitedStatesBaseUrl: String,
    japanBaseUrl: String
) {
    private val endpoints = mapOf(
        TranslationServiceRegion.Default to defaultBaseUrl.normalizedBaseUrl(),
        TranslationServiceRegion.UnitedStates to unitedStatesBaseUrl.normalizedBaseUrl(),
        TranslationServiceRegion.Japan to japanBaseUrl.normalizedBaseUrl()
    )

    fun resolve(region: TranslationServiceRegion): TranslationServiceEndpointSelection {
        val defaultUrl = endpoints.getValue(TranslationServiceRegion.Default)
        return TranslationServiceEndpointSelection(
            baseUrl = endpoints[region].orEmpty().ifBlank { defaultUrl },
            region = if (endpoints[region].isNullOrBlank()) {
                TranslationServiceRegion.Default
            } else {
                region
            }
        )
    }

    private fun String.normalizedBaseUrl(): String = trim().trimEnd('/')
}
