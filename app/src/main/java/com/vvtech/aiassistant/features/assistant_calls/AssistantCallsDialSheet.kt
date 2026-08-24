package com.vvtech.aiassistant.features.assistant_calls

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState

internal data class AssistantCallsDialSheetState(
    val dialNumber: String,
    val history: List<FinalCallRecord> = emptyList(),
    val translateEnabled: Boolean = false,
    val promptBeforeTranslationDial: Boolean = true,
    val myLanguage: String = "中文",
    val otherLanguage: String = "英文",
    val selectedCountryIso: String = "CN",
    val locationPromptShown: Boolean = false,
    val locationSystemPermissionRequested: Boolean = false,
    val callLogPermissionRequested: Boolean = false,
    val activeTranslationProviderTitle: String = "Qwen LT Flash",
    val activeTranslationProvider: String = "QWEN_OMNI_PLUS",
    val availableTranslationProviders: Set<String> = setOf("QWEN_OMNI_PLUS", "DOUBAO"),
    val translationModelQuality: TranslationModelNetworkQualityState =
        TranslationModelNetworkQualityState()
)

internal data class AssistantCallsDialSheetCallbacks(
    val onHistorySelect: (DialTargetSelection) -> Unit = {},
    val onHistoryCall: (DialTargetSelection) -> Unit = {},
    val onTranslateToggle: (Boolean) -> Unit = {},
    val onPromptBeforeTranslationDialChange: (Boolean) -> Unit = {},
    val onMyLanguageChange: (String) -> Unit = {},
    val onOtherLanguageChange: (String) -> Unit = {},
    val onSelectedCountryChange: (String) -> Unit = {},
    val onLocationPromptShownChange: (Boolean) -> Unit = {},
    val onLocationSystemPermissionRequestedChange: (Boolean) -> Unit = {},
    val onCallLogPermissionRequestedChange: (Boolean) -> Unit = {},
    val onSelectTranslationProvider: (String) -> Unit = {},
    val onRefreshTranslationModelQuality: () -> Unit = {},
    val onDigit: (String) -> Unit,
    val onDelete: () -> Unit,
    val onClose: () -> Unit,
    val onDial: () -> Unit
)

@Composable
internal fun AssistantCallsDialSheet(
    state: AssistantCallsDialSheetState,
    callbacks: AssistantCallsDialSheetCallbacks
) {
    val dialNumber = state.dialNumber
    val history = state.history
    val translateEnabled = state.translateEnabled
    val promptBeforeTranslationDial = state.promptBeforeTranslationDial
    val myLanguage = state.myLanguage
    val otherLanguage = state.otherLanguage
    val selectedCountryIso = state.selectedCountryIso
    val activeTranslationProviderTitle = state.activeTranslationProviderTitle
    val activeTranslationProvider = state.activeTranslationProvider
    val availableTranslationProviders = state.availableTranslationProviders
    val translationModelQuality = state.translationModelQuality
    val onHistorySelect = callbacks.onHistorySelect
    val onTranslateToggle = callbacks.onTranslateToggle
    val onPromptBeforeTranslationDialChange = callbacks.onPromptBeforeTranslationDialChange
    val onMyLanguageChange = callbacks.onMyLanguageChange
    val onOtherLanguageChange = callbacks.onOtherLanguageChange
    val onSelectedCountryChange = callbacks.onSelectedCountryChange
    val onSelectTranslationProvider = callbacks.onSelectTranslationProvider
    val onRefreshTranslationModelQuality = callbacks.onRefreshTranslationModelQuality
    val onDigit = callbacks.onDigit
    val onDelete = callbacks.onDelete
    val onClose = callbacks.onClose
    val onDial = callbacks.onDial
    val context = LocalContext.current
    val contactDirectory = rememberDialContactDirectoryState()
    val contactSuggestions = remember(dialNumber, contactDirectory.contacts) {
        dialContactSuggestions(dialNumber, contactDirectory.contacts)
    }
    val locationGate = rememberDialerLocationPermissionGate(
        translateEnabled = translateEnabled,
        consent = DialerLocationConsentState(
            promptShown = state.locationPromptShown,
            systemPermissionRequested = state.locationSystemPermissionRequested
        ),
        callbacks = DialerLocationConsentCallbacks(
            onPromptShownChange = callbacks.onLocationPromptShownChange,
            onSystemPermissionRequestedChange =
                callbacks.onLocationSystemPermissionRequestedChange,
            onTranslationEnabledChange = onTranslateToggle
        )
    )
    val callLogPermission = rememberDialerCallLogPermissionState(
        locationDecisionComplete = locationGate.decisionComplete,
        permissionRequested = state.callLogPermissionRequested,
        onPermissionRequestedChange = callbacks.onCallLogPermissionRequestedChange
    )
    val systemRecentCalls = rememberDeviceCallLogState(
        loadEnabled = callLogPermission.permissionGranted
    )
    val recentCalls = remember(history, contactDirectory.contacts, systemRecentCalls) {
        mergeDialRecentCalls(
            systemRecords = systemRecentCalls,
            localRecords = localDialRecentCalls(
                translationDialRecentCallRecords(history),
                contactDirectory.contacts
            ),
            limit = MaxDialRecentCalls
        )
    }
    var showTranslationModelSheet by remember { mutableStateOf(false) }
    var showTranslationPresets by remember { mutableStateOf(false) }
    var showCountrySelector by remember { mutableStateOf(false) }
    var showCrossBorderConfirmation by remember { mutableStateOf(false) }
    val selectedCountry = remember(selectedCountryIso) { dialCountryByIso(selectedCountryIso) }
    val locationState = rememberDialCountryLocationState()
    val requestDial = {
        if (
            shouldConfirmCrossBorderTranslationCall(
                translationEnabled = translateEnabled,
                locationCountryIso = locationState.country?.iso,
                calleeCountryIso = selectedCountryIso
            )
        ) {
            showCrossBorderConfirmation = true
        } else {
            onDial()
        }
    }
    BackHandler(
        enabled = !showCountrySelector && !showTranslationModelSheet && !showTranslationPresets,
        onBack = onClose
    )
    BackHandler(enabled = showTranslationModelSheet) {
        showTranslationModelSheet = false
    }
    BackHandler(enabled = showTranslationPresets) {
        showTranslationPresets = false
    }

    Box(
        Modifier
            .fillMaxSize()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = {}
            )
            .background(Color(0xFFF8F9FC))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = 28.dp)
        ) {
            DialerNumberHeader(
                dialNumber = dialNumber,
                country = selectedCountry,
                onCountryClick = { showCountrySelector = true }
            )
            if (dialNumber.isBlank()) {
                DialHistoryList(
                    history = recentCalls,
                    onSelect = onHistorySelect,
                    modifier = Modifier.weight(1f).padding(top = 24.dp)
                )
            } else {
                AssistantDialContactSuggestionList(
                    suggestions = contactSuggestions,
                    onSelect = onHistorySelect,
                    modifier = Modifier.weight(1f).padding(top = 24.dp)
                )
            }
            TranslationLanguageLine(
                translateEnabled = translateEnabled,
                modelTitle = activeTranslationProviderTitle,
                myLanguage = myLanguage,
                otherLanguage = otherLanguage,
                onModelClick = { showTranslationModelSheet = true },
                onClick = { showTranslationPresets = true }
            )
            AssistantDialPad(
                onDigit = { digit ->
                    val atDigitLimit = dialNumber.count(Char::isDigit) >= MaxDialNationalDigits
                    if (digit.any(Char::isDigit) && atDigitLimit) {
                        Toast.makeText(context, currentAppText("号码最多输入14位", "Phone number can contain up to 14 digits"), Toast.LENGTH_SHORT).show()
                    } else {
                        onDigit(digit)
                    }
                }
            )
            DialerBottomActions(
                translateEnabled = translateEnabled,
                onClose = onClose,
                onDial = {
                    if (dialNumber.isBlank() && recentCalls.isNotEmpty()) {
                        val first = recentCalls.first()
                        onHistorySelect(
                            DialTargetSelection(
                                phoneNumber = first.phoneNumber,
                                displayName = first.displayName,
                                callKind = first.kind,
                                countryIso = first.countryIso,
                                callerLanguageCode = first.callerLanguageCode,
                                calleeLanguageCode = first.calleeLanguageCode
                            )
                        )
                    } else if (translateEnabled && promptBeforeTranslationDial) {
                        showTranslationPresets = true
                    } else {
                        requestDial()
                    }
                },
                onDelete = onDelete
            )
            Spacer(Modifier.padding(bottom = 32.dp))
        }

        AssistantTranslationModelSheetHost(
            visible = showTranslationModelSheet,
            selectedProvider = activeTranslationProvider,
            availableProviders = availableTranslationProviders,
            quality = translationModelQuality,
            onRefresh = onRefreshTranslationModelQuality,
            onSelect = onSelectTranslationProvider,
            onDismiss = { showTranslationModelSheet = false }
        )
        TranslationPresetsSheet(
            visible = showTranslationPresets,
            translateEnabled = translateEnabled,
            promptBeforeDial = promptBeforeTranslationDial,
            myLanguage = myLanguage,
            otherLanguage = otherLanguage,
            onTranslateEnabledChange = locationGate.onTranslationToggleRequested,
            onPromptBeforeDialChange = onPromptBeforeTranslationDialChange,
            onMyLanguageChange = onMyLanguageChange,
            onOtherLanguageChange = onOtherLanguageChange,
            onDismiss = { showTranslationPresets = false },
            onCall = {
                showTranslationPresets = false
                requestDial()
            }
        )
        CrossBorderTranslationCallDialog(
            visible = showCrossBorderConfirmation,
            onCancel = { showCrossBorderConfirmation = false },
            onContinue = {
                showCrossBorderConfirmation = false
                onDial()
            }
        )
        DialerLocationPermissionDialogHost(locationGate)
        if (showCountrySelector) {
            val selectAndClose: (String) -> Unit = { iso ->
                onSelectedCountryChange(iso)
                showCountrySelector = false
            }
            DialCountrySelectorPage(
                selectedIso = selectedCountryIso,
                onSelect = selectAndClose,
                onLocationCountrySelected = selectAndClose,
                onBack = { showCountrySelector = false }
            )
        }
    }
}
