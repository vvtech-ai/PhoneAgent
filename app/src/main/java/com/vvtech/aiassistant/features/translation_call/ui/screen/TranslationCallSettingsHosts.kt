package com.vvtech.aiassistant.features.translation_call.ui.screen

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.features.assistant.ProviderSettingsArgs
import com.vvtech.aiassistant.features.assistant.SettingsPageArgs
import com.vvtech.aiassistant.features.assistant_settings.AssistantSipAccountSettingsCallbacks
import com.vvtech.aiassistant.features.assistant_settings.AssistantSipAccountSettingsPage
import com.vvtech.aiassistant.features.assistant_settings.AssistantSipAccountSettingsState
import com.vvtech.aiassistant.features.assistant_translation.DomesticOriginalAudioSettingsCallbacks
import com.vvtech.aiassistant.features.assistant_translation.DomesticOriginalAudioSettingsPage
import com.vvtech.aiassistant.features.assistant_translation.DomesticOriginalAudioSettingsState
import com.vvtech.aiassistant.features.assistant_shell.AssistantSettingsNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.returnToAssistantSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsVisibility
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSettingsStateHolder

@Composable
internal fun RegionAwareSipAccountSettingsHost(
    settings: SettingsPageArgs,
    navigation: AssistantSettingsNavigationCallbacks,
    region: TranslationRegionState,
    visibility: TranslationCallSettingsVisibility
) {
    if (!visibility.showSipAccounts) {
        LaunchedEffect(region) {
            returnToAssistantSettings(navigation)
        }
        return
    }
    AssistantSipAccountSettingsPage(
        state = AssistantSipAccountSettingsState(
            selectedDomesticAccountId = settings.selectedDomesticSipAccountId,
            selectedInternationalAccountId = settings.selectedInternationalSipAccountId
        ),
        callbacks = AssistantSipAccountSettingsCallbacks(
            onBack = { returnToAssistantSettings(navigation) },
            onSelectDomesticAccount = settings.onSelectDomesticSipAccount,
            onSelectInternationalAccount = settings.onSelectInternationalSipAccount
        ),
        appLanguage = settings.appLanguage
    )
}

@Composable
internal fun RegionAwareTranslationProviderSettingsHost(
    providers: ProviderSettingsArgs,
    navigation: AssistantSettingsNavigationCallbacks,
    holder: TranslationCallSettingsStateHolder,
    region: TranslationRegionState,
    visibility: TranslationCallSettingsVisibility,
    regionalSettings: TranslationCallSettings
) {
    when {
        visibility.showOverseasProvider -> OverseasTranslationSettingsPage(
            state = OverseasTranslationSettingsUiState(
                provider = regionalSettings.overseasProvider,
                serviceRegion = regionalSettings.serviceRegion
            ),
            callbacks = OverseasTranslationSettingsCallbacks(
                onBack = { returnToAssistantSettings(navigation) },
                onSelectProvider = holder::selectOverseasProvider,
                onSelectServiceRegion = holder::selectServiceRegion
            )
        )
        visibility.showDomesticProvider -> DomesticOriginalAudioSettingsPage(
            state = DomesticOriginalAudioSettingsState(
                enabled = regionalSettings.playOriginalAudio,
                gainPercent = regionalSettings.originalAudioGainPercent,
                volumePercent = regionalSettings.originalAudioVolumePercent
            ),
            callbacks = DomesticOriginalAudioSettingsCallbacks(
                onEnabledChange = holder::setPlayOriginalAudio,
                onGainPercentChange = holder::setOriginalAudioGainPercent,
                onVolumePercentChange = holder::setOriginalAudioVolumePercent
            ),
            onBack = { returnToAssistantSettings(navigation) }
        )
        else -> LaunchedEffect(region) {
            returnToAssistantSettings(navigation)
        }
    }
}

@Composable
internal fun OriginalAudioSettingsHost(
    navigation: AssistantSettingsNavigationCallbacks,
    holder: TranslationCallSettingsStateHolder,
    settings: TranslationCallSettings
) {
    DomesticOriginalAudioSettingsPage(
        state = DomesticOriginalAudioSettingsState(
            enabled = settings.playOriginalAudio,
            gainPercent = settings.originalAudioGainPercent,
            volumePercent = settings.originalAudioVolumePercent
        ),
        callbacks = DomesticOriginalAudioSettingsCallbacks(
            onEnabledChange = holder::setPlayOriginalAudio,
            onGainPercentChange = holder::setOriginalAudioGainPercent,
            onVolumePercentChange = holder::setOriginalAudioVolumePercent
        ),
        onBack = { returnToAssistantSettings(navigation) }
    )
}
