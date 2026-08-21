package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_calls.AssistantClientSipCallPage
import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheetCallbacks
import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheetState
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactPermissionConsentDialog
import kotlinx.coroutines.delay
import com.vvtech.aiassistant.features.assistant.AssistantOverlayHostArgs
import com.vvtech.aiassistant.features.assistant.FinalAiCallPageV3
import com.vvtech.aiassistant.features.assistant.FinalBottomTabBar
import com.vvtech.aiassistant.features.assistant.FinalCallsDialSheetV2
import com.vvtech.aiassistant.features.assistant.FinalFadeDurationMs
import com.vvtech.aiassistant.features.assistant.FinalFadeEase
import com.vvtech.aiassistant.features.assistant.FinalMotionDurationMs
import com.vvtech.aiassistant.features.assistant.FinalMotionEase
import com.vvtech.aiassistant.features.assistant.FinalOtaUpdateDialog
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalVoiceCloneFeatureVisible
import com.vvtech.aiassistant.features.assistant.V61InitializationOverlay
import com.vvtech.aiassistant.features.assistant.V88PermissionDialog
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import com.vvtech.aiassistant.features.assistant.V88TrustedCalleeGuideSheet
import com.vvtech.aiassistant.features.assistant.V88TrustedCalleeSecondDialog
import com.vvtech.aiassistant.features.assistant.V88VoiceCloneGuideSheet
import com.vvtech.aiassistant.features.assistant_model.V88VoiceModelSheet
import com.vvtech.aiassistant.features.assistant_conversation.ui.overlay.AssistantDeviceContactSelectionOverlay
import com.vvtech.aiassistant.features.assistant_conversation.ui.overlay.AssistantLogoutConfirmOverlay
import com.vvtech.aiassistant.features.assistant_conversation.ui.overlay.AssistantNetworkStatusOverlay
import com.vvtech.aiassistant.features.translation_call.ui.TranslationCallScreen

@Composable
internal fun BoxScope.AssistantNavigationCallOverlaySection(args: AssistantOverlayHostArgs) {
    with(args) {
        if (showBottomTabs) {
            FinalBottomTabBar(
                selected = currentMainTab,
                onSelect = onSelectMainTab,
                onDialClick = onOpenDialSheet,
                hidden = assistantNavHidden || showCallsDialSheet ||
                    clientCallState.visible || translationCallState.visible,
                taskBadgeCount = taskBadgeCount,
                appLanguage = appLanguage
            )
        }

        if (pureVoiceMode && currentPage == FinalPage.SingleFlow && assistantUiState.showAiCallPage) {
            FinalAiCallPageV3(
                targetName = selectedRestaurantTitle
                    ?: assistantUiState.callPageData.name.ifBlank { "目标对象" },
                phoneNumber = assistantUiState.agentCallSpec?.phoneNumber.orEmpty(),
                callModelTitle = activeCallModelTitle,
                seconds = aiCallSeconds,
                callData = assistantUiState.callPageData,
                callUiMode = assistantUiState.callUiMode,
                handoffInFlight = assistantUiState.handoffInFlight,
                callMonitorState = assistantUiState.callMonitorState,
                callMonitorAudioRouteState = assistantUiState.callMonitorAudioRouteState,
                onHangup = onAiHangup,
                onMonitorToggle = onAiMonitorToggle,
                onAudioRouteSelect = onAiAudioRouteSelect
            )
        }

        AnimatedVisibility(
            visible = showCallsDialSheet,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth(),
            enter = fadeIn(
                animationSpec = tween(
                    durationMillis = FinalFadeDurationMs,
                    easing = FinalFadeEase
                )
            ) + slideInVertically(
                animationSpec = tween(
                    durationMillis = FinalMotionDurationMs,
                    easing = FinalMotionEase
                ),
                initialOffsetY = { (it * 12) / 10 }
            ),
            exit = fadeOut(
                animationSpec = tween(
                    durationMillis = FinalFadeDurationMs,
                    easing = FinalFadeEase
                )
            ) + slideOutVertically(
                animationSpec = tween(
                    durationMillis = FinalMotionDurationMs,
                    easing = FinalMotionEase
                ),
                targetOffsetY = { (it * 12) / 10 }
            )
        ) {
            FinalCallsDialSheetV2(
                state = AssistantCallsDialSheetState(
                    dialNumber = dialInput,
                    history = dialHistory,
                    translateEnabled = translateDialEnabled,
                    promptBeforeTranslationDial = promptBeforeTranslationDial,
                    myLanguage = myTranslationLanguage,
                    otherLanguage = otherTranslationLanguage,
                    selectedCountryIso = selectedDialCountryIso,
                    locationPromptShown = dialLocationPromptShown,
                    locationSystemPermissionRequested =
                        dialLocationSystemPermissionRequested,
                    callLogPermissionRequested = dialCallLogPermissionRequested,
                    activeTranslationProviderTitle = activeTranslationProviderTitle,
                    activeTranslationProvider = activeTranslationProvider,
                    availableTranslationProviders = availableTranslationProviders,
                    translationModelQuality = translationModelQuality
                ),
                callbacks = AssistantCallsDialSheetCallbacks(
                    onHistorySelect = onDialHistorySelect,
                    onHistoryCall = onDialHistoryCall,
                    onTranslateToggle = onTranslateDialToggle,
                    onPromptBeforeTranslationDialChange = onPromptBeforeTranslationDialChange,
                    onMyLanguageChange = onMyTranslationLanguageChange,
                    onOtherLanguageChange = onOtherTranslationLanguageChange,
                    onSelectedCountryChange = onSelectedDialCountryChange,
                    onLocationPromptShownChange = onDialLocationPromptShownChange,
                    onLocationSystemPermissionRequestedChange =
                        onDialLocationSystemPermissionRequestedChange,
                    onCallLogPermissionRequestedChange =
                        onDialCallLogPermissionRequestedChange,
                    onSelectTranslationProvider = onSelectTranslationProvider,
                    onRefreshTranslationModelQuality = onRefreshTranslationModelQuality,
                    onDigit = onDialDigit,
                    onDelete = onDialDelete,
                    onClose = onDialSheetClose,
                    onDial = onDial
                )
            )
        }

        LaunchedEffect(clientCallState.visible) {
            while (clientCallState.visible) {
                delay(1_000)
                onClientCallTick()
            }
        }
        if (clientCallState.visible) {
            AssistantClientSipCallPage(
                state = clientCallState,
                onToggleMuted = onClientCallToggleMuted,
                onToggleSpeaker = onClientCallToggleSpeaker,
                onDtmf = onClientCallDtmf,
                onHangup = onClientCallHangup
            )
        }
        LaunchedEffect(translationCallState.visible) {
            while (translationCallState.visible) {
                delay(1_000)
                onTranslationCallTick()
            }
        }
        if (translationCallState.visible) {
            TranslationCallScreen(
                state = translationCallState,
                onAction = onTranslationCallAction
            )
        }
    }
}

@Composable
internal fun BoxScope.AssistantPermissionGuideModelOverlaySection(args: AssistantOverlayHostArgs) {
    with(args) {
        AssistantNetworkStatusOverlay(
            mode = networkMode,
            blocking = showNetworkBlocker,
            onRetry = onNetworkRetry,
            onDismissBlocker = onDismissNetworkBlocker
        )

        requestedPermission?.let { permission ->
            when (assistantPermissionDialogPresentation(permission)) {
                AssistantPermissionDialogPresentation.Contact ->
                    AssistantContactPermissionConsentDialog(
                        onAllow = { onPermissionAllow(permission) },
                        onDeny = { onPermissionDeny(permission) }
                    )
                AssistantPermissionDialogPresentation.Legacy ->
                    V88PermissionDialog(
                        kind = permission,
                        onAllow = { onPermissionAllow(permission) },
                        onDeny = { onPermissionDeny(permission) }
                    )
            }
        }

        V88VoiceCloneGuideSheet(
            visible = FinalVoiceCloneFeatureVisible && showVoiceCloneGuide,
            onStart = onStartVoiceCloneGuide,
            onDismiss = onDismissVoiceCloneGuide,
            onNeverAsk = onNeverAskVoiceCloneGuide
        )

        V88TrustedCalleeGuideSheet(
            visible = showTrustedCalleeGuide,
            onAuthorize = onAuthorizeTrustedCallee,
            onDismiss = onDismissTrustedCalleeGuide,
            onNeverAsk = onNeverAskTrustedCalleeGuide
        )

        V88TrustedCalleeSecondDialog(
            visible = showTrustedCalleeSecondModal,
            onConfirm = onConfirmTrustedCalleeSecondModal
        )

        if (showVoiceModelSheet) {
            V88VoiceModelSheet(
                selectedId = selectedVoiceModelId,
                models = voiceModelOptions,
                onSelect = onSelectVoiceModel,
                onClose = onCloseVoiceModelSheet,
                latencySource = voiceModelLatencySource
            )
        }
    }
}

@Composable
internal fun BoxScope.AssistantAccountOverlaySection(args: AssistantOverlayHostArgs) {
    with(args) {
        otaUpdateDialog?.let { dialogState ->
            FinalOtaUpdateDialog(
                state = dialogState,
                installState = otaInstallState,
                onDismiss = { onDismissOtaDialog(dialogState) },
                onPrimaryAction = onOtaPrimaryAction
            )
        }

        AssistantLogoutConfirmOverlay(
            visible = showLogoutConfirm,
            onConfirm = onConfirmLogout,
            onCancel = onCancelLogout
        )

        if (assistantUiState.identityInitOverlayVisible) {
            V61InitializationOverlay(
                saving = identityOverlaySaving,
                error = identityOverlayError,
                completionOnly = identityCompletionOnly,
                initialIdentity = initialIdentity,
                callProviderOptions = voiceModelOptions,
                initialTranslationProvider = initialTranslationProvider,
                onDismiss = onDismissIdentityOverlay,
                onSkipIdentityForSession = onSkipIdentityForSession,
                onSubmit = onSubmitIdentityOverlay,
                onSelectCallProvider = onSelectInitializationCallProvider,
                onSelectTranslationProvider = onSelectInitializationTranslationProvider
            )
        }

        AssistantDeviceContactSelectionOverlay(
            state = assistantUiState.agentDeviceContactSelection,
            onConfirm = onAgentDeviceContactSelectionConfirm,
            onCancel = onAgentDeviceContactSelectionCancel
        )
    }
}
