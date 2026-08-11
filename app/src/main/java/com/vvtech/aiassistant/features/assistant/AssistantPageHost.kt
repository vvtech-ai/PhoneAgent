package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable

@Composable
internal fun AssistantPageHost(
    args: AssistantPageHostArgs,
    onPageVisibilityChanged: (FinalPage, Boolean) -> Unit = { _, _ -> }
) {
    FinalRootPageFrame(
        pageBottomInset = args.navigation.pageBottomInset,
        currentPage = args.navigation.currentPage,
        onPageEntered = { page ->
            if (page == FinalPage.Tasks) {
                args.navigation.onTaskPageEntered()
            }
        },
        onPageVisibilityChanged = onPageVisibilityChanged
    ) { targetPage ->
        AssistantPageHostContent(
            targetPage = targetPage,
            args = args
        )
    }
}

@Composable
private fun AssistantPageHostContent(
    targetPage: FinalPage,
    args: AssistantPageHostArgs
) {
    when (targetPage) {
        FinalPage.Home,
        FinalPage.Assistant -> AssistantConversationPageHost(
            targetPage = targetPage,
            navigation = args.navigation,
            assistant = args.assistant
        )

        FinalPage.SingleFlow -> AssistantSingleFlowPageHost(
            navigation = args.navigation,
            assistant = args.assistant,
            contact = args.contact
        )

        FinalPage.Contacts,
        FinalPage.ContactDetail,
        FinalPage.ContactDirectoryDetail,
        FinalPage.MyIdentity,
        FinalPage.ContactMethods,
        FinalPage.ContactMethodEdit -> AssistantContactPageHost(
            buildAssistantContactPageHostArgs(
                targetPage = targetPage,
                navigation = args.navigation,
                contact = args.contact
            )
        )

        FinalPage.Calls,
        FinalPage.AgentCallDetail,
        FinalPage.AiCall,
        FinalPage.Result,
        FinalPage.NormalCall,
        FinalPage.TranslateCall -> AssistantCallPageHost(
            buildAssistantCallPageHostArgs(
                targetPage = targetPage,
                navigation = args.navigation,
                call = args.call,
                assistantUiState = args.assistant.assistantUiState,
                pureVoiceMode = args.assistant.pureVoiceMode
            )
        )

        FinalPage.Tasks,
        FinalPage.Settings,
        FinalPage.SipAccountSettings,
        FinalPage.RealtimeProviderSettings,
        FinalPage.RealtimeCallVoiceSettings,
        FinalPage.TranslationProviderSettings,
        FinalPage.OriginalAudioSettings -> AssistantTaskSettingsPageHost(
            targetPage = targetPage,
            navigation = args.navigation,
            assistant = args.assistant,
            contact = args.contact,
            task = args.task,
            settings = args.settings,
            providerSettings = args.providerSettings,
            voiceClone = args.voiceClone
        )

        FinalPage.DeveloperTools,
        FinalPage.OutboundNumberEdit -> AssistantDeveloperPermissionPageHost(
            targetPage = targetPage,
            navigation = args.navigation,
            assistant = args.assistant,
            settings = args.settings,
            permissionDeveloper = args.permissionDeveloper
        )

        FinalPage.VoiceIdentitySettings,
        FinalPage.VoiceCloneSettings -> AssistantVoiceClonePageHost(
            targetPage = targetPage,
            navigation = args.navigation,
            settings = args.settings,
            voiceClone = args.voiceClone
        )

        FinalPage.Clarify,
        FinalPage.Confirm -> AssistantClarifyConfirmPageHost(
            targetPage = targetPage,
            navigation = args.navigation,
            confirmClarify = args.confirmClarify
        )
    }
}
