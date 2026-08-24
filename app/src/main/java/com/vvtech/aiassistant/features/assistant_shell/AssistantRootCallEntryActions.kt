package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantCallRequest
import com.vvtech.aiassistant.callengine.AssistantClientCallController
import com.vvtech.aiassistant.domain.phone.DialPhoneNumberPolicy
import com.vvtech.aiassistant.domain.phone.DialPhoneTargetResult
import com.vvtech.aiassistant.features.assistant.FinalDeveloperModeUnlockCode
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.normalizeDialNumber
import com.vvtech.aiassistant.features.assistant_calls.ContactDialNumberResult
import com.vvtech.aiassistant.features.assistant_calls.DialRecentCallKind
import com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection
import com.vvtech.aiassistant.features.assistant_calls.dialCountryByIso
import com.vvtech.aiassistant.features.assistant_calls.dialTranslationLanguageCodes
import com.vvtech.aiassistant.features.assistant_calls.normalizeDialTarget
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallLaunchInput
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallLaunchResult

internal data class AssistantRootCallEntryActionDeps(
    val callDialState: AssistantCallDialState,
    val clientCallController: AssistantClientCallController,
    val onStartTranslationCall: (TranslationCallLaunchInput) -> TranslationCallLaunchResult,
    val permissionOverlayState: AssistantPermissionOverlayState,
    val taskEntry: AssistantTaskEntryState,
    val selectedContactSystemDialPhoneProvider: () -> String,
    val selectedContactNameProvider: () -> String = { "" },
    val onLaunchSystemDialer: (String) -> Boolean,
    val translationProviderProvider: () -> String,
    val selectedDomesticSipAccountIdProvider: () -> String,
    val selectedInternationalSipAccountIdProvider: () -> String,
    val onBlockOffline: () -> Boolean,
    val onHasMicrophonePermissionForVoiceEntry: () -> Boolean,
    val onLaunchTranslationAudioPermission: () -> Unit,
    val onEnableDeveloperMode: () -> Unit,
    val onShowDeveloperModeUnlocked: () -> Unit,
    val onApplyCallsMainTab: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val currentMainTabProvider: () -> FinalMainTab = { FinalMainTab.Home },
    val currentPageProvider: () -> com.vvtech.aiassistant.features.assistant.FinalPage = {
        com.vvtech.aiassistant.features.assistant.FinalPage.Home
    },
    val onShowMessage: (String) -> Unit = {}
)

internal class AssistantRootCallEntryActions(
    private val deps: AssistantRootCallEntryActionDeps
) {
    fun openCallsDialSheet(selectTranslate: Boolean? = null) {
        deps.callDialState.captureReturnDestination(
            deps.currentMainTabProvider(),
            deps.currentPageProvider()
        )
        deps.onCloseHomeComposer()
        selectTranslate?.let { deps.callDialState.dialer.translateEnabled = it }
        deps.callDialState.openDialSheet()
    }

    fun unlockDeveloperModeFromDial(): Boolean {
        val normalizedInput = normalizeDialNumber(deps.callDialState.dialer.dialInput)
        if (normalizedInput != "$FinalDeveloperModeUnlockCode*#") {
            return false
        }
        deps.onEnableDeveloperMode()
        deps.onShowDeveloperModeUnlocked()
        deps.callDialState.dialer.clearNumbers()
        return true
    }

    fun startRealtimeTranslationCallFromDial() {
        startClientSipCall(translation = true)
    }

    fun runNormalCallFromDial(): Boolean {
        val country = dialCountryByIso(deps.callDialState.dialer.selectedCountryIso)
        val target = when (val result = DialPhoneNumberPolicy.resolve(
            countryIso = country.iso,
            countryDialCode = country.dialCode,
            rawNumber = deps.callDialState.dialer.dialInput
        )) {
            is DialPhoneTargetResult.Ready -> result.target
            is DialPhoneTargetResult.Invalid -> {
                if (deps.callDialState.dialer.dialInput.any(Char::isDigit)) {
                    deps.onShowMessage(DialPhoneNumberPolicy.ChinaMobileValidationMessage)
                }
                return false
            }
        }
        deps.callDialState.dialer.lastDialedNumber = deps.callDialState.dialer.dialInput
        return deps.onLaunchSystemDialer(target.systemDialNumber)
    }

    fun runNormalCallToNumber(phoneNumber: String): Boolean {
        return if (deps.callDialState.dialer.prepareContactNumber(
                raw = phoneNumber,
                translationMode = false
            ) is
            ContactDialNumberResult.Supported
        ) {
            deps.callDialState.dialer.translateEnabled = false
            startClientSipCall(translation = false)
        } else {
            false
        }
    }

    fun runNormalCallFromContact(): Boolean {
        return openDialFromContact()
    }

    fun runHistoryCall(target: DialTargetSelection): Boolean {
        if (target.callKind != DialRecentCallKind.TRANSLATION) {
            if (normalizeDialTarget(target.phoneNumber).isBlank()) {
                deps.onShowMessage(currentAppText("通话记录号码格式不正确", "Call history number format is invalid"))
                return false
            }
            return deps.onLaunchSystemDialer(target.phoneNumber)
        }
        return when (deps.callDialState.dialer.restoreHistoryTarget(target)) {
            is ContactDialNumberResult.Supported -> startClientSipCall(translation = true)
            ContactDialNumberResult.UnsupportedCountry -> {
                deps.onShowMessage(currentAppText("暂不支持该号码国家或地区", "This number's country or region is not supported yet"))
                false
            }
            ContactDialNumberResult.Invalid,
            ContactDialNumberResult.TooLong -> {
                deps.onShowMessage(currentAppText("通话记录号码格式不正确", "Call history number format is invalid"))
                false
            }
        }
    }

    fun openDialFromContact(): Boolean {
        val target = deps.selectedContactSystemDialPhoneProvider().trim()
        if (normalizeDialTarget(target).isBlank()) {
            deps.onShowMessage(currentAppText("联系人号码格式不正确", "Contact number format is invalid"))
            return false
        }
        return deps.onLaunchSystemDialer(target)
    }

    fun runPendingPermissionAction(): Boolean = runAssistantPendingPermissionAction(
        action = deps.permissionOverlayState.takePendingPermissionAction(),
        callbacks = AssistantPendingPermissionActionCallbacks(
            onRunDial = { runNormalCallFromDial() },
            onRunTranslationDial = { startRealtimeTranslationCallFromDial() },
            onRunContactCall = { runNormalCallFromContact() },
            onConfirmAttachmentUploaded = { deps.taskEntry.confirmAttachmentUploaded = true }
        )
    )

    fun runDialSheetAction() {
        if (!unlockDeveloperModeFromDial()) {
            if (deps.callDialState.dialer.translateEnabled) {
                startClientSipCall(translation = true)
            } else {
                runNormalCallFromDial()
            }
        }
    }

    private fun startClientSipCall(translation: Boolean): Boolean {
        val country = dialCountryByIso(deps.callDialState.dialer.selectedCountryIso)
        val target = when (val result = DialPhoneNumberPolicy.resolve(
            countryIso = country.iso,
            countryDialCode = country.dialCode,
            rawNumber = deps.callDialState.dialer.dialInput
        )) {
            is DialPhoneTargetResult.Ready -> result.target
            is DialPhoneTargetResult.Invalid -> {
                deps.onShowMessage(
                    if (country.iso.equals("CN", ignoreCase = true)) {
                        DialPhoneNumberPolicy.ChinaMobileValidationMessage
                    } else {
                        result.message
                    }
                )
                return false
            }
        }
        if (translation && target.systemOnly) {
            deps.callDialState.dialer.lastDialedNumber = deps.callDialState.dialer.dialInput
            return deps.onLaunchSystemDialer(target.systemDialNumber)
        }
        if (deps.onBlockOffline()) return false
        if (!deps.onHasMicrophonePermissionForVoiceEntry()) {
            deps.callDialState.dialer.translateEnabled = translation
            deps.onLaunchTranslationAudioPermission()
            return true
        }
        val number = target.canonicalNumber
        if (number.isBlank()) return false
        val languages = dialTranslationLanguageCodes(
            myLanguage = deps.callDialState.dialer.myLanguage,
            otherLanguage = deps.callDialState.dialer.otherLanguage
        )
        deps.callDialState.dialer.lastDialedNumber = deps.callDialState.dialer.dialInput
        if (translation) {
            return when (
                val result = deps.onStartTranslationCall(
                    TranslationCallLaunchInput(
                        rawNumber = deps.callDialState.dialer.dialInput,
                        displayName = deps.callDialState.dialer.targetDisplayName,
                        defaultCountryDialCode = country.dialCode,
                        countryIso = country.iso,
                        myLanguage = languages.caller,
                        peerLanguage = languages.callee,
                        domesticSipAccountId = deps.selectedDomesticSipAccountIdProvider(),
                        internationalSipAccountId = deps.selectedInternationalSipAccountIdProvider()
                    )
                )
            ) {
                TranslationCallLaunchResult.Started -> true
                is TranslationCallLaunchResult.Rejected -> {
                    deps.onShowMessage(result.message)
                    false
                }
            }
        }
        return deps.clientCallController.start(
            AssistantCallRequest(
                phoneNumber = number,
                displayName = deps.callDialState.dialer.targetDisplayName,
                countryDialCode = country.dialCode,
                countryIso = country.iso,
                mode = AssistantCallMode.NORMAL,
                provider = deps.translationProviderProvider(),
                myLanguage = languages.caller,
                peerLanguage = languages.callee,
                selectedDomesticSipAccountId = deps.selectedDomesticSipAccountIdProvider(),
                selectedInternationalSipAccountId = deps.selectedInternationalSipAccountIdProvider()
            )
        )
    }
}

internal fun AssistantNavigationState.applyCallsMainTab() {
    applyMainTab(FinalMainTab.Calls)
}
