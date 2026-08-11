package com.vvtech.aiassistant.features.assistant

internal fun finalPageForMainTab(tab: FinalMainTab): FinalPage = when (tab) {
    FinalMainTab.Home -> FinalPage.Home
    FinalMainTab.Contacts -> FinalPage.Contacts
    FinalMainTab.Assistant -> FinalPage.Assistant
    FinalMainTab.Calls -> FinalPage.Calls
    FinalMainTab.Tasks -> FinalPage.Tasks
    FinalMainTab.Settings -> FinalPage.Settings
}

internal fun finalPageForIdentityInitFallback(tab: FinalMainTab): FinalPage = when (tab) {
    FinalMainTab.Home -> FinalPage.Home
    FinalMainTab.Contacts -> FinalPage.Contacts
    FinalMainTab.Assistant -> FinalPage.Home
    FinalMainTab.Calls -> FinalPage.Calls
    FinalMainTab.Tasks -> FinalPage.Tasks
    FinalMainTab.Settings -> FinalPage.Settings
}

internal fun resolveFinalSubPageTarget(
    page: FinalPage,
    pureVoiceMode: Boolean
): FinalPage {
    return if (page == FinalPage.Result) {
        if (pureVoiceMode) FinalPage.SingleFlow else FinalPage.Assistant
    } else {
        page
    }
}

internal fun finalBackTargetPage(
    currentPage: FinalPage,
    pureVoiceMode: Boolean,
    normalCallReturnPage: String
): FinalPage {
    return when (currentPage) {
        FinalPage.ContactDetail -> FinalPage.Contacts
        FinalPage.ContactDirectoryDetail -> FinalPage.Contacts
        FinalPage.MyIdentity -> FinalPage.Settings
        FinalPage.SipAccountSettings -> FinalPage.Settings
        FinalPage.DeveloperTools -> FinalPage.Settings
        FinalPage.OutboundNumberEdit -> FinalPage.Settings
        FinalPage.RealtimeProviderSettings -> FinalPage.Settings
        FinalPage.OriginalAudioSettings -> FinalPage.Settings
        FinalPage.RealtimeCallVoiceSettings -> FinalPage.RealtimeProviderSettings
        FinalPage.VoiceIdentitySettings -> FinalPage.RealtimeCallVoiceSettings
        FinalPage.VoiceCloneSettings -> FinalPage.RealtimeCallVoiceSettings
        FinalPage.ContactMethods -> FinalPage.Settings
        FinalPage.ContactMethodEdit -> FinalPage.ContactMethods
        FinalPage.Clarify -> FinalPage.Assistant
        FinalPage.Confirm -> FinalPage.Clarify
        FinalPage.AiCall -> if (pureVoiceMode) FinalPage.SingleFlow else FinalPage.Confirm
        FinalPage.Result -> if (pureVoiceMode) FinalPage.SingleFlow else FinalPage.Assistant
        FinalPage.AgentCallDetail -> FinalPage.Calls
        FinalPage.NormalCall -> runCatching { FinalPage.valueOf(normalCallReturnPage) }.getOrDefault(FinalPage.Calls)
        else -> FinalPage.Home
    }
}

internal fun finalPageRequiresIdentityBeforeAssistantEntry(page: FinalPage): Boolean {
    return page == FinalPage.Assistant || page == FinalPage.SingleFlow
}
