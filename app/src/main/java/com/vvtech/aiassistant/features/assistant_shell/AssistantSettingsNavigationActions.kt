package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalPage

internal data class AssistantSettingsNavigationCallbacks(
    val onPageChange: (FinalPage) -> Unit,
    val onOpenSubPage: (FinalPage) -> Unit
)

internal fun openAssistantSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.Settings)
}

internal fun openAssistantDeveloperTools(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.DeveloperTools)
}

internal fun openAssistantContactMethods(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.ContactMethods)
}

internal fun openAssistantMyIdentity(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.MyIdentity)
}

internal fun openAssistantSipAccountSettings(
    callbacks: AssistantSettingsNavigationCallbacks,
    allowedByRegion: Boolean = true
) {
    if (allowedByRegion) {
        callbacks.onOpenSubPage(FinalPage.SipAccountSettings)
    } else {
        callbacks.onPageChange(FinalPage.Settings)
    }
}

internal fun openAssistantRealtimeProviderSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.RealtimeProviderSettings)
}

internal fun openAssistantRealtimeCallVoiceSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.RealtimeCallVoiceSettings)
}

internal fun openAssistantTranslationProviderSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.TranslationProviderSettings)
}

internal fun openAssistantOriginalAudioSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.OriginalAudioSettings)
}

internal fun openAssistantVoiceIdentitySettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.VoiceIdentitySettings)
}

internal fun openAssistantOutboundNumberEdit(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onOpenSubPage(FinalPage.OutboundNumberEdit)
}

internal fun returnToAssistantSettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onPageChange(FinalPage.Settings)
}

internal fun returnToAssistantVoiceIdentitySettings(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onPageChange(FinalPage.VoiceIdentitySettings)
}

internal fun returnToAssistantDeveloperTools(callbacks: AssistantSettingsNavigationCallbacks) {
    callbacks.onPageChange(FinalPage.DeveloperTools)
}
