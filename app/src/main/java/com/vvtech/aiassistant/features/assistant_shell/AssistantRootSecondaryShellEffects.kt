package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_initialization.AssistantInitializationRecoveryCallbacks
import com.vvtech.aiassistant.features.assistant_initialization.AssistantInitializationRecoveryEffect
import com.vvtech.aiassistant.features.assistant_initialization.AssistantInitializationSnapshot

internal data class AssistantRootSecondaryShellEffectsArgs(
    val context: Context,
    val prefs: SharedPreferences,
    val assistantUiState: Index9AssistantUiState,
    val assistantViewModel: AssistantViewModel,
    val rootRuntimeGraph: AssistantRootRuntimeGraph,
    val rootActivityLaunchers: AssistantRootActivityLaunchers,
    val lifecycleOwner: LifecycleOwner
)

@Composable
internal fun AssistantRootSecondaryShellEffects(
    args: AssistantRootSecondaryShellEffectsArgs
) {
    val context = args.context
    val assistantUiState = args.assistantUiState
    val assistantViewModel = args.assistantViewModel
    val state = args.rootRuntimeGraph.state
    val runtime = args.rootRuntimeGraph.runtime
    val navigationState = state.navigation
    val currentPage = navigationState.currentPage
    val previousMainTab = navigationState.previousMainTab
    val pureVoiceMode = state.rootSettings.pureVoiceMode

    AssistantRootStartupEffect(
        AssistantRootStartupEffectArgs(
            context = context,
            prefs = args.prefs,
            assistantViewModel = assistantViewModel,
            callbacks = AssistantRootStartupCallbacks(
                onContactsPermissionGrantedChange = { state.permissionOverlay.contactsPermissionGranted = it },
                onPhonePermissionGrantedChange = { state.permissionOverlay.phonePermissionGranted = it },
                onTrustedCalleeStartupReadyChange = { runtime.auth.trustedCalleeStartupReady = it },
                onLaunchStartupPermissions = { args.rootActivityLaunchers.startupPermissions.launch(it) },
                onRefreshOutboundNumber = { runtime.outbound.refresh() },
                onRefreshRealTasks = { runtime.task.refresh() },
                onRefreshRealtimeCallProvider = { runtime.provider.refreshRealtimeCallProvider() },
                onRefreshRealtimeCallVoice = { runtime.provider.refreshRealtimeCallVoice() },
                onRefreshTranslationProvider = { runtime.provider.refreshTranslationProvider() },
                onRefreshVoiceCloneStatus = runtime.voiceClone::refreshStatus,
                onRefreshDeviceContacts = { runtime.contact.refreshDeviceContacts() },
                onRefreshUserIdentity = runtime.contact::refreshUserIdentity,
                onRefreshContactDirectory = runtime.contact::refreshContactDirectory
            )
        )
    )
    AssistantInitializationRecoveryEffect(
        context = context,
        lifecycleOwner = args.lifecycleOwner,
        enabled = AccountIdentityProvider.accountId.isNotBlank(),
        snapshot = AssistantInitializationSnapshot(
            identity = runtime.contact.userIdentityLoadState,
            callProvider = runtime.provider.realtimeProviderLoadState,
            translationProvider = runtime.provider.translationProviderLoadState
        ),
        callbacks = AssistantInitializationRecoveryCallbacks(
            refreshIdentity = runtime.contact::refreshUserIdentity,
            refreshCallProvider = runtime.provider::refreshRealtimeCallProvider,
            refreshTranslationProvider = runtime.provider::refreshTranslationProvider
        )
    )
    AssistantIdentityInitOverlayShellEffect(
        AssistantIdentityInitOverlayShellEffectArgs(
            currentPage = currentPage,
            previousMainTab = previousMainTab,
            identityInitOverlayVisible = assistantUiState.identityInitOverlayVisible,
            runtime = runtime.contact,
            onNavigateFallback = { fallbackTab, fallbackPage ->
                navigationState.applyMainTab(fallbackTab, fallbackPage)
            }
        )
    )
    AssistantAgentPermissionShellEffect(
        AssistantAgentPermissionShellEffectArgs(
            context = context,
            agentPermissionRequest = assistantUiState.agentPermissionRequest,
            agentPendingToolCallId = assistantUiState.agentPendingToolCallId,
            isAgentPermissionGranted = { request -> isAssistantAgentPermissionGranted(context, request) },
            onAgentPermissionResult = assistantViewModel::onAgentPermissionResult,
            onActiveAgentPermissionRequestChange = state.transientOverlay::updateActiveAgentPermissionRequest,
            onLaunchPermission = { args.rootActivityLaunchers.agentPermission.launch(it) }
        )
    )
    FinalLocationPermissionResumeEffect(
        context = context,
        lifecycleOwner = args.lifecycleOwner,
        onLoadLocationIfPermitted = assistantViewModel::loadLocationIfPermitted
    )
    AssistantTrustedCalleeRuntimeShellEffect(
        AssistantTrustedCalleeRuntimeShellEffectArgs(
            currentPage = currentPage,
            runtime = runtime.auth
        )
    )
    AssistantAiCallPageSyncEffect(
        AssistantAiCallPageSyncEffectArgs(
            showAiCallPage = assistantUiState.showAiCallPage,
            pureVoiceMode = pureVoiceMode,
            currentPage = currentPage,
            onMainTabChange = navigationState::setMainTab,
            onPageChange = navigationState::navigateTo
        )
    )
}
