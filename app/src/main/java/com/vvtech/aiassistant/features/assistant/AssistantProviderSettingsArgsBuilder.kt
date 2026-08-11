package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse

internal class AssistantProviderSettingsArgsBuilderInput(
    val realtime: RealtimeProviderSettingsInput,
    val translation: TranslationProviderSettingsInput,
    val callbacks: ProviderSettingsCallbacksInput
)

internal class RealtimeProviderSettingsInput(
    val activeRealtimeProviderSummary: String,
    val realtimeProviderLoading: Boolean,
    val realtimeProviderError: String?,
    val realtimeProviderResponse: RealtimeCallProviderResponse?,
    val realtimeProviderSwitching: Boolean,
    val activeRealtimeCallVoiceSummary: String,
    val realtimeCallVoiceLoading: Boolean,
    val realtimeCallVoiceError: String?,
    val realtimeCallVoiceResponse: RealtimeCallVoiceResponse?,
    val realtimeCallVoiceSwitching: Boolean
)

internal class TranslationProviderSettingsInput(
    val activeTranslationProviderSummary: String,
    val translationProviderLoading: Boolean,
    val translationProviderError: String?,
    val translationProviderResponse: RealtimeTranslationProviderResponse?,
    val translationProviderSwitching: Boolean,
    val translationQwenVoicePreference: String,
    val translationQwenLanguageSettings: TranslationProviderLanguageSettings
)

internal class ProviderSettingsCallbacksInput(
    val onRefreshRealtimeProvider: (Boolean) -> Unit,
    val onRefreshRealtimeCallVoice: (Boolean) -> Unit,
    val onRefreshTranslationProvider: (Boolean) -> Unit,
    val onSwitchRealtimeCallProvider: (String) -> Unit,
    val onSwitchRealtimeCallVoice: (String?, String) -> Unit,
    val onTranslationQwenVoicePreferenceChange: (String) -> Unit,
    val onTranslationQwenLanguageSettingsChange: (TranslationProviderLanguageSettings) -> Unit,
    val onSwitchTranslationProvider: (String) -> Unit
)

internal fun buildAssistantProviderSettingsArgs(
    input: AssistantProviderSettingsArgsBuilderInput
): ProviderSettingsArgs = ProviderSettingsArgs().also { args ->
    with(input.realtime) {
        args.activeRealtimeProviderSummary = activeRealtimeProviderSummary
        args.realtimeProviderLoading = realtimeProviderLoading
        args.realtimeProviderError = realtimeProviderError
        args.realtimeProviderResponse = realtimeProviderResponse
        args.realtimeProviderSwitching = realtimeProviderSwitching
        args.activeRealtimeCallVoiceSummary = activeRealtimeCallVoiceSummary
        args.realtimeCallVoiceLoading = realtimeCallVoiceLoading
        args.realtimeCallVoiceError = realtimeCallVoiceError
        args.realtimeCallVoiceResponse = realtimeCallVoiceResponse
        args.realtimeCallVoiceSwitching = realtimeCallVoiceSwitching
    }
    with(input.translation) {
        args.activeTranslationProviderSummary = activeTranslationProviderSummary
        args.translationProviderLoading = translationProviderLoading
        args.translationProviderError = translationProviderError
        args.translationProviderResponse = translationProviderResponse
        args.translationProviderSwitching = translationProviderSwitching
        args.translationQwenVoicePreference = translationQwenVoicePreference
        args.translationQwenLanguageSettings = translationQwenLanguageSettings
    }
    with(input.callbacks) {
        args.onRefreshRealtimeProvider = onRefreshRealtimeProvider
        args.onRefreshRealtimeCallVoice = onRefreshRealtimeCallVoice
        args.onRefreshTranslationProvider = onRefreshTranslationProvider
        args.onSwitchRealtimeCallProvider = onSwitchRealtimeCallProvider
        args.onSwitchRealtimeCallVoice = onSwitchRealtimeCallVoice
        args.onTranslationQwenVoicePreferenceChange = onTranslationQwenVoicePreferenceChange
        args.onTranslationQwenLanguageSettingsChange = onTranslationQwenLanguageSettingsChange
        args.onSwitchTranslationProvider = onSwitchTranslationProvider
    }
}
