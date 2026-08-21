package com.vvtech.aiassistant.features.assistant

import android.content.SharedPreferences
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.model.ConversationListItem

internal class AssistantTaskPageArgsBuilderInput(
    val visibleTaskRecords: List<FinalTaskRecord>,
    val realTaskLoading: Boolean,
    val conversationLoading: Boolean,
    val realTaskError: String?,
    val conversationError: String?,
    val conversations: List<ConversationListItem>,
    val onRefreshRealTasks: () -> Unit
)

internal class AssistantSettingsArgsBuilderInput(
    val main: SettingsMainInput,
    val sipAccount: SettingsSipAccountInput,
    val outbound: SettingsOutboundInput,
    val callbacks: SettingsCallbacksInput
)

internal class SettingsMainInput(
    val developerModeEnabled: Boolean,
    val appLanguage: AppLanguage,
    val selectedVoiceModelTitle: String,
    val otaUpdateChecking: Boolean,
    val logUploadInProgress: Boolean,
    val prefs: SharedPreferences
)

internal class SettingsSipAccountInput(
    val selectedDomesticAccountId: String,
    val selectedInternationalAccountId: String,
    val onSelectDomesticAccount: (String) -> Unit,
    val onSelectInternationalAccount: (String) -> Unit
)

internal class SettingsOutboundInput(
    val outboundNumber: String,
    val outboundDraft: String,
    val outboundError: String?,
    val outboundLoading: Boolean,
    val outboundConfigured: Boolean,
    val outboundSaving: Boolean,
    val outboundDeleting: Boolean
)

internal class SettingsCallbacksInput(
    val onAppLanguageChange: (AppLanguage) -> Unit,
    val onSelectedMethodReset: () -> Unit,
    val onShowVoiceModelSheetChange: (Boolean) -> Unit,
    val onOpenTrustedCalleeAuthorization: () -> Unit,
    val onCheckVersionUpdate: () -> Unit,
    val onUploadLogs: () -> Unit,
    val onShowLogoutConfirmChange: (Boolean) -> Unit,
    val onOutboundDraftChange: (String) -> Unit,
    val onOutboundErrorChange: (String?) -> Unit,
    val onRefreshOutboundNumber: () -> Unit,
    val onSaveOutboundNumber: () -> Unit,
    val onDeleteOutboundNumber: () -> Unit
)

internal fun buildAssistantTaskPageArgs(
    input: AssistantTaskPageArgsBuilderInput
): TaskPageArgs = TaskPageArgs().also { args ->
    args.visibleTaskRecords = input.visibleTaskRecords
    args.realTaskLoading = input.realTaskLoading
    args.conversationLoading = input.conversationLoading
    args.realTaskError = input.realTaskError
    args.conversationError = input.conversationError
    args.conversations = input.conversations
    args.onRefreshRealTasks = input.onRefreshRealTasks
}

internal fun buildAssistantSettingsPageArgs(
    input: AssistantSettingsArgsBuilderInput
): SettingsPageArgs = SettingsPageArgs().also { args ->
    with(input.main) {
        args.developerModeEnabled = developerModeEnabled
        args.appLanguage = appLanguage
        args.selectedVoiceModelTitle = selectedVoiceModelTitle
        args.otaUpdateChecking = otaUpdateChecking
        args.logUploadInProgress = logUploadInProgress
        args.prefs = prefs
    }
    with(input.sipAccount) {
        args.selectedDomesticSipAccountId = selectedDomesticAccountId
        args.selectedInternationalSipAccountId = selectedInternationalAccountId
        args.onSelectDomesticSipAccount = onSelectDomesticAccount
        args.onSelectInternationalSipAccount = onSelectInternationalAccount
    }
    with(input.outbound) {
        args.outboundNumber = outboundNumber
        args.outboundDraft = outboundDraft
        args.outboundError = outboundError
        args.outboundLoading = outboundLoading
        args.outboundConfigured = outboundConfigured
        args.outboundSaving = outboundSaving
        args.outboundDeleting = outboundDeleting
    }
    with(input.callbacks) {
        args.onAppLanguageChange = onAppLanguageChange
        args.onSelectedMethodReset = onSelectedMethodReset
        args.onShowVoiceModelSheetChange = onShowVoiceModelSheetChange
        args.onOpenTrustedCalleeAuthorization = onOpenTrustedCalleeAuthorization
        args.onCheckVersionUpdate = onCheckVersionUpdate
        args.onUploadLogs = onUploadLogs
        args.onShowLogoutConfirmChange = onShowLogoutConfirmChange
        args.onOutboundDraftChange = onOutboundDraftChange
        args.onOutboundErrorChange = onOutboundErrorChange
        args.onRefreshOutboundNumber = onRefreshOutboundNumber
        args.onSaveOutboundNumber = onSaveOutboundNumber
        args.onDeleteOutboundNumber = onDeleteOutboundNumber
    }
}
