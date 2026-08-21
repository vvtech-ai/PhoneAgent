package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import com.vvtech.aiassistant.features.app_logs.AssistantLogUploadRuntimeController
import com.vvtech.aiassistant.features.assistant.*

internal data class AssistantRootPageHostSecondaryArgs(
    val settings: SettingsPageArgs,
    val providerSettings: ProviderSettingsArgs,
    val voiceClone: VoiceCloneArgs,
    val confirmClarify: ConfirmClarifyArgs,
    val permissionDeveloper: PermissionDeveloperArgs
)

internal data class AssistantRootPageHostSecondaryArgsFactoryDeps(
    val context: Context,
    val prefs: SharedPreferences,
    val runtime: AssistantRootPageHostSecondaryRuntimeDeps,
    val state: AssistantRootPageHostSecondaryStateDeps,
    val launchers: AssistantRootActivityLaunchers,
    val values: AssistantRootPageHostSecondaryValueDeps,
    val callbacks: AssistantRootPageHostSecondaryCallbacks
)

internal data class AssistantRootPageHostSecondaryRuntimeDeps(
    val auth: AssistantAuthRuntimeController,
    val contact: AssistantContactRuntimeController,
    val outbound: AssistantOutboundNumberRuntimeController,
    val provider: AssistantProviderRuntimeController,
    val ota: AssistantOtaRuntimeController,
    val logUpload: AssistantLogUploadRuntimeController,
    val voiceClone: AssistantVoiceCloneRuntimeController
)

internal data class AssistantRootPageHostSecondaryStateDeps(
    val settings: AssistantRootSettingsPreferenceState,
    val taskEntry: AssistantTaskEntryState,
    val permissionOverlay: AssistantPermissionOverlayState,
    val transientOverlay: AssistantRootTransientOverlayState,
    val taskFlowActions: AssistantRootTaskFlowActions
)

internal data class AssistantRootPageHostSecondaryValueDeps(
    val selectedVoiceModelId: String,
    val taskEntryOptions: AssistantTaskEntryOptionsState
)

internal data class AssistantRootPageHostSecondaryCallbacks(
    val blockIfOffline: () -> Boolean,
    val onResetDialerLocationPermissionAndOpenDialSheet: () -> Unit
)

internal fun buildAssistantRootPageHostSecondaryArgs(
    deps: AssistantRootPageHostSecondaryArgsFactoryDeps
): AssistantRootPageHostSecondaryArgs =
    AssistantRootPageHostSecondaryArgs(
        settings = buildAssistantSettingsPageArgs(deps.settingsInput()),
        providerSettings = buildAssistantProviderSettingsArgs(deps.providerSettingsInput()),
        voiceClone = buildAssistantVoiceCloneArgs(deps.voiceCloneInput()),
        confirmClarify = buildAssistantClarifyConfirmArgs(deps.clarifyConfirmInput()),
        permissionDeveloper = buildAssistantPermissionDeveloperArgs(deps.permissionDeveloperInput())
    )

private fun AssistantRootPageHostSecondaryArgsFactoryDeps.settingsInput() =
    AssistantSettingsArgsBuilderInput(
        main = SettingsMainInput(
            developerModeEnabled = state.settings.developerModeEnabled,
            appLanguage = state.settings.appLanguage,
            selectedVoiceModelTitle = selectedVoiceModelTitle(values.selectedVoiceModelId),
            otaUpdateChecking = runtime.ota.otaUpdateChecking,
            logUploadInProgress = runtime.logUpload.logUploadInProgress,
            prefs = prefs
        ),
        sipAccount = SettingsSipAccountInput(
            selectedDomesticAccountId = state.settings.selectedDomesticSipAccountId,
            selectedInternationalAccountId = state.settings.selectedInternationalSipAccountId,
            onSelectDomesticAccount = state.settings::updateDomesticSipAccountId,
            onSelectInternationalAccount = state.settings::updateInternationalSipAccountId
        ),
        outbound = SettingsOutboundInput(
            outboundNumber = runtime.outbound.number,
            outboundDraft = runtime.outbound.draft,
            outboundError = runtime.outbound.error,
            outboundLoading = runtime.outbound.loading,
            outboundConfigured = runtime.outbound.configured,
            outboundSaving = runtime.outbound.saving,
            outboundDeleting = runtime.outbound.deleting
        ),
        callbacks = SettingsCallbacksInput(
            onAppLanguageChange = state.settings::updateAppLanguage,
            onSelectedMethodReset = runtime.contact::resetSelection,
            onShowVoiceModelSheetChange = state.transientOverlay::setVoiceModelSheetVisible,
            onOpenTrustedCalleeAuthorization = runtime.auth::openTrustedCalleeAuthorization,
            onCheckVersionUpdate = {
                runtime.ota.checkVersionUpdate(showNoUpdatePrompt = true, startupCheck = false)
            },
            onUploadLogs = runtime.logUpload::uploadAppLogs,
            onShowLogoutConfirmChange = { runtime.auth.showLogoutConfirm = it },
            onOutboundDraftChange = { runtime.outbound.draft = it },
            onOutboundErrorChange = { runtime.outbound.error = it },
            onRefreshOutboundNumber = { runtime.outbound.refresh() },
            onSaveOutboundNumber = runtime.outbound::save,
            onDeleteOutboundNumber = runtime.outbound::delete
        )
    )

private fun AssistantRootPageHostSecondaryArgsFactoryDeps.providerSettingsInput() =
    AssistantProviderSettingsArgsBuilderInput(
        realtime = RealtimeProviderSettingsInput(
            activeRealtimeProviderSummary = runtime.provider.activeRealtimeProviderSummary,
            realtimeProviderLoading = runtime.provider.realtimeProviderLoading,
            realtimeProviderError = runtime.provider.realtimeProviderError,
            realtimeProviderResponse = runtime.provider.realtimeProviderResponse,
            realtimeProviderSwitching = runtime.provider.realtimeProviderSwitching,
            activeRealtimeCallVoiceSummary = runtime.provider.activeRealtimeCallVoiceSummary,
            realtimeCallVoiceLoading = runtime.provider.realtimeCallVoiceLoading,
            realtimeCallVoiceError = runtime.provider.realtimeCallVoiceError,
            realtimeCallVoiceResponse = runtime.provider.realtimeCallVoiceResponse,
            realtimeCallVoiceSwitching = runtime.provider.realtimeCallVoiceSwitching
        ),
        translation = TranslationProviderSettingsInput(
            activeTranslationProviderSummary = runtime.provider.activeTranslationProviderSummary,
            translationProviderLoading = runtime.provider.translationProviderLoading,
            translationProviderError = runtime.provider.translationProviderError,
            translationProviderResponse = runtime.provider.translationProviderResponse,
            translationProviderSwitching = runtime.provider.translationProviderSwitching,
            translationQwenVoicePreference = state.settings.translationQwenVoicePreference,
            translationQwenLanguageSettings = state.settings.translationQwenLanguageSettings
        ),
        callbacks = ProviderSettingsCallbacksInput(
            onRefreshRealtimeProvider = { force -> runtime.provider.refreshRealtimeCallProvider(force = force) },
            onRefreshRealtimeCallVoice = { force -> runtime.provider.refreshRealtimeCallVoice(force = force) },
            onRefreshTranslationProvider = { force -> runtime.provider.refreshTranslationProvider(force = force) },
            onSwitchRealtimeCallProvider = runtime.provider::switchRealtimeCallProvider,
            onSwitchRealtimeCallVoice = runtime.provider::switchRealtimeCallVoiceSelection,
            onTranslationQwenVoicePreferenceChange = state.settings::updateTranslationQwenVoicePreference,
            onTranslationQwenLanguageSettingsChange = state.settings::updateTranslationQwenLanguageSettings,
            onSwitchTranslationProvider = runtime.provider::switchTranslationProvider
        )
    )

private fun AssistantRootPageHostSecondaryArgsFactoryDeps.voiceCloneInput() =
    AssistantVoiceCloneArgsBuilderInput(
        status = runtime.voiceClone.statusInput,
        recording = runtime.voiceClone.recordingInput,
        guide = runtime.voiceClone.guideInput,
        callbacks = runtime.voiceClone.callbacksInput {
            launchers.voiceCloneAudioPermission.launch(Manifest.permission.RECORD_AUDIO)
        }
    )

private fun AssistantRootPageHostSecondaryArgsFactoryDeps.clarifyConfirmInput() =
    AssistantClarifyConfirmArgsBuilderInput(
        options = ClarifyConfirmOptionsInput(
            restaurantOptions = values.taskEntryOptions.restaurantOptions,
            fallbackOptions = values.taskEntryOptions.fallbackOptions,
            selectedRestaurant = values.taskEntryOptions.selectedRestaurant,
            selectedFallbacks = values.taskEntryOptions.selectedFallbacks,
            defaultMethod = runtime.contact.defaultMethod
        ),
        selection = ClarifyConfirmSelectionInput(
            selectedRestaurantId = state.taskEntry.selectedRestaurantId,
            selectedFallbackIds = state.taskEntry.selectedFallbackIds,
            requiredFallbackIds = state.taskEntry.requiredFallbackIds
        ),
        confirmation = ClarifyConfirmConfirmationInput(
            restaurantConfirmed = state.taskEntry.restaurantConfirmed,
            fallbackConfirmed = state.taskEntry.fallbackConfirmed,
            confirmingRestaurantId = state.taskEntry.confirmingRestaurantId,
            confirmingFallbackId = state.taskEntry.confirmingFallbackId,
            confirmAttachmentUploaded = state.taskEntry.confirmAttachmentUploaded,
            storagePermissionGranted = state.permissionOverlay.storagePermissionGranted
        ),
        callbacks = ClarifyConfirmCallbacksInput(
            onSelectedRestaurantIdChange = { state.taskEntry.selectedRestaurantId = it },
            onRestaurantConfirmedChange = { state.taskEntry.restaurantConfirmed = it },
            onConfirmingRestaurantIdChange = { state.taskEntry.confirmingRestaurantId = it },
            onFallbackConfirmedChange = { state.taskEntry.fallbackConfirmed = it },
            onConfirmingFallbackIdChange = { state.taskEntry.confirmingFallbackId = it },
            onConfirmAttachmentUploadedChange = { state.taskEntry.confirmAttachmentUploaded = it },
            blockIfOffline = callbacks.blockIfOffline,
            onRequestedPermissionNameChange = { state.permissionOverlay.requestedPermissionName = it },
            onPendingPermissionActionChange = { state.permissionOverlay.pendingPermissionAction = it }
        )
    )

private fun AssistantRootPageHostSecondaryArgsFactoryDeps.permissionDeveloperInput() =
    AssistantPermissionDeveloperArgsBuilderInput(
        state = AssistantPermissionDeveloperState(
            developerDataMode = state.settings.developerDataModeName,
            networkMode = state.permissionOverlay.networkMode,
            context = context
        ),
        callbacks = AssistantPermissionDeveloperCallbacks(
            onNetworkModeNameChange = { state.permissionOverlay.networkModeName = it },
            onShowNetworkBlockerChange = { state.permissionOverlay.showNetworkBlocker = it },
            onMicrophonePermissionGrantedChange = { state.permissionOverlay.microphonePermissionGranted = it },
            onStoragePermissionGrantedChange = { state.permissionOverlay.storagePermissionGranted = it },
            onContactsPermissionGrantedChange = { state.permissionOverlay.contactsPermissionGranted = it },
            onPhonePermissionGrantedChange = { state.permissionOverlay.phonePermissionGranted = it },
            onResetDialerLocationPermissionAndOpenDialSheet =
                callbacks.onResetDialerLocationPermissionAndOpenDialSheet,
            onApplyDeveloperDataMode = state.taskFlowActions::applyDeveloperDataMode
        )
    )

private fun selectedVoiceModelTitle(selectedVoiceModelId: String): String =
    V88VoiceModelOptions.firstOrNull { it.id == selectedVoiceModelId }?.title
        ?: V88VoiceModelOptions.first().title
