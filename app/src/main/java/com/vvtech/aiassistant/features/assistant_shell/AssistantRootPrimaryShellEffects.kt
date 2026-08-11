package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.logging.AppFileLogger

internal data class AssistantRootPrimaryShellEffectsArgs(
    val context: Context,
    val lifecycleOwner: LifecycleOwner,
    val assistantViewModel: AssistantViewModel,
    val rootRuntimeGraph: AssistantRootRuntimeGraph
)

@Composable
internal fun AssistantRootPrimaryShellEffects(
    args: AssistantRootPrimaryShellEffectsArgs
) {
    val context = args.context
    val lifecycleOwner = args.lifecycleOwner
    val assistantViewModel = args.assistantViewModel
    val rootRuntimeGraph = args.rootRuntimeGraph
    val state = rootRuntimeGraph.state
    val runtime = rootRuntimeGraph.runtime
    val navigationState = state.navigation
    val taskPageRefreshState = state.taskPageRefresh
    val currentPage = navigationState.currentPage
    val currentMainTab = navigationState.currentMainTab
    val previousMainTab = navigationState.previousMainTab

    AssistantVoiceLifecycleShellEffects(
        AssistantVoiceLifecycleShellEffectsArgs(
            voiceLanguage = state.rootSettings.voiceLanguage,
            assistantViewModel = assistantViewModel,
            onDisposeVoiceCloneRuntime = runtime.voiceClone::disposeResources
        )
    )
    AssistantPageLifecycleShellEffects(
        lifecycleOwner = lifecycleOwner,
        currentPage = currentPage,
        currentMainTab = currentMainTab,
        previousMainTab = previousMainTab
    )
    LaunchedEffect(currentPage) {
        if (currentPage == FinalPage.Calls) {
            AppFileLogger.i("CALL_HISTORY_REFRESH", "reason=call_page_enter page=Calls")
            assistantViewModel.refreshHistory()
        }
    }
    AssistantAuthCodeRetryShellEffect(
        AssistantAuthCodeRetryShellEffectArgs(
            mockLoggedIn = runtime.auth.mockLoggedIn,
            authCodeRetrySeconds = runtime.auth.authCodeRetrySeconds,
            onRetrySecondsChange = runtime.auth::onRetrySecondsChange
        )
    )
    AssistantAccountIdentityShellEffect(
        AssistantAccountIdentityShellEffectArgs(
            activeAccountId = runtime.auth.activeAccountId,
            mockLoggedIn = runtime.auth.mockLoggedIn,
            onLoadCallRecordsForAccount = state.callRecord::loadForAccount,
            onClearCallRecordsForCurrentAccount = {
                state.callRecord.clearForAccount(runtime.auth.activeAccountId, persist = false)
            },
            onAccountIdentityChanged = assistantViewModel::onAccountIdentityChanged
        )
    )
    AssistantSystemContactsSyncShellEffects(
        AssistantSystemContactsSyncShellEffectsArgs(
            context = context,
            lifecycleOwner = lifecycleOwner,
            contactsPermissionGranted = state.permissionOverlay.contactsPermissionGranted,
            mockLoggedIn = runtime.auth.mockLoggedIn,
            onRefreshDeviceContacts = { runtime.contact.refreshDeviceContacts() }
        )
    )
    AssistantBackNavigationEffect(
        AssistantBackNavigationEffectArgs(
            state = AssistantBackNavigationState(
                currentPage = currentPage,
                previousMainTab = previousMainTab,
                pureVoiceMode = state.rootSettings.pureVoiceMode,
                normalCallReturnPage = state.callDial.normalCallReturnPage
            ),
            callbacks = AssistantBackNavigationCallbacks(
                nextDeferredRefreshId = taskPageRefreshState::nextDeferredRefreshId,
                onSingleFlowBack = { closeId, targetTab, targetPage ->
                    pauseAssistantSingleFlowForSystemBack(
                        closeId = closeId,
                        targetTab = targetTab,
                        targetPage = targetPage,
                        callbacks = AssistantSingleFlowBackCallbacks(
                            onPauseTaskConversationAndResetLocalUi =
                                assistantViewModel::pauseTaskConversationAndResetLocalUi,
                            onScheduleTaskRefreshAfterClose =
                                runtime.task::scheduleRefreshAfterClose,
                            onApplyMainTab = navigationState::applyMainTab
                        )
                    )
                },
                onNavigateBack = navigationState::navigateTo
            )
        )
    )
    AssistantPageResourceShellEffects(
        context = context,
        currentPage = currentPage,
        translationCallAudioClient = runtime.translation.audioClient
    )
    AssistantTranslationRuntimeShellEffects(
        AssistantTranslationRuntimeShellEffectsArgs(
            context = context,
            lifecycleOwner = lifecycleOwner,
            currentPage = currentPage,
            runtime = runtime.translation
        )
    )
    AssistantSingleFlowBackgroundShellEffect(
        currentPage = currentPage,
        lifecycleOwner = lifecycleOwner,
        assistantViewModel = assistantViewModel
    )
}
