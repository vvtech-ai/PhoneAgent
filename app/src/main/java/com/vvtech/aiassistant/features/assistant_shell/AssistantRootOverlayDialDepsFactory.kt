package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_calls.ContactDialNumberResult

internal fun buildAssistantRootOverlayDialDeps(
    deps: AssistantRootHostArgsFactoryDeps,
    onShowMessage: (String) -> Unit
): AssistantRootOverlayDialDeps = with(deps) {
    AssistantRootOverlayDialDeps(
        showCallsDialSheet = state.callDial.showCallsDialSheet,
        dialInput = state.callDial.dialer.dialInput,
        translateDialEnabled = state.callDial.dialer.translateEnabled,
        onTranslateDialToggle = { state.callDial.dialer.translateEnabled = it },
        activeTranslationProviderTitle = runtime.realtimeTranslation.selectedProviderTitle,
        activeTranslationProvider = runtime.realtimeTranslation.selectedProviderId,
        onSelectTranslationProvider = runtime.realtimeTranslation::selectProvider,
        onDialDigit = state.callDial.dialer::appendDigit,
        onDialDelete = state.callDial.dialer::deleteDigit,
        onDialSheetClose = state.callDial::hideDialSheet,
        onDial = actions.callEntry::runDialSheetAction,
        onOpenDialSheet = { actions.callEntry.openCallsDialSheet() },
        history = runtime.callRecord.records,
        onHistoryCall = actions.callEntry::runHistoryCall,
        onHistorySelect = { target ->
            when (state.callDial.dialer.restoreHistoryTarget(target)) {
                is ContactDialNumberResult.Supported -> Unit
                ContactDialNumberResult.UnsupportedCountry ->
                    onShowMessage(
                        currentAppText(
                            "暂不支持该联系人国家或地区",
                            "This contact's country or region is not supported yet"
                        )
                    )
                ContactDialNumberResult.Invalid,
                ContactDialNumberResult.TooLong ->
                    onShowMessage(
                        currentAppText(
                            "联系人号码格式不正确",
                            "Contact number format is invalid"
                        )
                    )
            }
        },
        promptBeforeTranslationDial = state.callDial.dialer.promptBeforeTranslationCall,
        onPromptBeforeTranslationDialChange = {
            state.callDial.dialer.promptBeforeTranslationCall = it
        },
        myLanguage = state.callDial.dialer.myLanguage,
        otherLanguage = state.callDial.dialer.otherLanguage,
        onMyLanguageChange = { state.callDial.dialer.myLanguage = it },
        onOtherLanguageChange = { state.callDial.dialer.otherLanguage = it },
        selectedCountryIso = state.callDial.dialer.selectedCountryIso,
        onSelectedCountryChange = state.callDial.dialer::selectCountry,
        locationPromptShown = state.callDial.dialer.locationPromptShown,
        onLocationPromptShownChange = {
            state.callDial.dialer.locationPromptShown = it
        },
        locationSystemPermissionRequested =
            state.callDial.dialer.locationSystemPermissionRequested,
        onLocationSystemPermissionRequestedChange = {
            state.callDial.dialer.locationSystemPermissionRequested = it
        },
        callLogPermissionRequested = state.callDial.dialer.callLogPermissionRequested,
        onCallLogPermissionRequestedChange = {
            state.callDial.dialer.callLogPermissionRequested = it
        },
        clientCallState = runtime.clientCallState,
        onClientCallTick = runtime.clientCall::tick,
        onClientCallToggleMuted = runtime.clientCall::toggleMuted,
        onClientCallToggleSpeaker = runtime.clientCall::toggleSpeaker,
        onClientCallDtmf = runtime.clientCall::sendDtmf,
        onClientCallHangup = runtime.clientCall::hangup
    )
}
