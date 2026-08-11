package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.shouldForceNewTaskVoiceEntryStart

internal data class AssistantVoiceInteractionStartRequest(
    val forceNewTaskEntry: Boolean,
    val useToggle: Boolean
)

internal data class AssistantVoiceInteractionPendingState(
    val accountId: String,
    val forceNewTaskEntry: Boolean,
    val useToggle: Boolean
)

internal data class AssistantVoiceEntryStartRequest(
    val initialCommand: String?,
    val startWithVoice: Boolean,
    val resumeExisting: Boolean,
    val initialSkillId: String? = null,
    val initialSkillOpening: String? = null,
    val selectedContact: SelectedContactTaskContext? = null
)

internal data class AssistantPendingVoiceEntryState(
    val initialCommand: String,
    val startInVoice: Boolean,
    val resumeExisting: Boolean,
    val active: Boolean,
    val accountId: String,
    val initialSkillId: String? = null,
    val initialSkillOpening: String? = null,
    val selectedContact: SelectedContactTaskContext? = null
)

internal data class AssistantVoiceEntryInvalidPendingResult(
    val reason: String,
    val pendingActive: Boolean,
    val pendingAccountId: String,
    val currentAccountId: String,
    val mockLoggedIn: Boolean
)

internal data class AssistantVoiceEntrySingleFlowPlan(
    val initialCommand: String,
    val startInVoice: Boolean,
    val forceNewVoiceEntryStart: Boolean,
    val initialSkillId: String? = null,
    val initialSkillOpening: String? = null,
    val selectedContact: SelectedContactTaskContext? = null
)

internal class AssistantVoiceEntryAccountCallbacks(
    val accountProvider: () -> AssistantVoicePermissionAccountState,
    val onSkipUnsignedVoiceInteraction: (AssistantVoicePermissionAccountState) -> Unit,
    val onSkipUnsignedVoiceEntry: (AssistantVoicePermissionAccountState) -> Unit
)

internal class AssistantVoiceEntryMicrophonePermissionCallbacks(
    val hasMicrophonePermission: () -> Boolean,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onLaunchVoiceEntryPermission: () -> Unit,
    val onLaunchVoiceInteractionPermission: () -> Unit
)

internal class AssistantVoiceEntryPendingCallbacks(
    val pendingProvider: () -> AssistantPendingVoiceEntryState,
    val onSavePendingVoiceEntry: (AssistantPendingVoiceEntryState) -> Unit,
    val onClearPendingVoiceEntry: () -> Unit,
    val onDropInvalidPending: (AssistantVoiceEntryInvalidPendingResult) -> Unit,
    val onSavePendingVoiceInteraction: (AssistantVoiceInteractionPendingState) -> Unit
)

internal class AssistantVoiceEntryFlowCallbacks(
    val onBlockOffline: () -> Boolean,
    val onBlockIdentityIncomplete: () -> Boolean,
    val onResetTaskConversationForNewEntry: (String) -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onOpenExistingSingleFlow: () -> Unit,
    val onOpenNewSingleFlow: (AssistantVoiceEntrySingleFlowPlan) -> Unit
)

internal class AssistantVoiceInteractionDispatchCallbacks(
    val onToggleVoiceInput: () -> Unit,
    val onStartNewTaskEntry: () -> Unit,
    val onApiMicClick: () -> Unit
)

internal fun checkAssistantVoiceEntryMicrophonePermission(
    permission: AssistantVoiceEntryMicrophonePermissionCallbacks
): Boolean {
    val granted = permission.hasMicrophonePermission()
    permission.onMicrophonePermissionGrantedChange(granted)
    return granted
}

internal fun startAssistantVoiceInteractionWithPermission(
    request: AssistantVoiceInteractionStartRequest,
    account: AssistantVoiceEntryAccountCallbacks,
    permission: AssistantVoiceEntryMicrophonePermissionCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks,
    dispatch: AssistantVoiceInteractionDispatchCallbacks
): Boolean {
    val currentAccount = account.accountProvider()
    if (currentAccount.currentAccountId.isBlank() || !currentAccount.mockLoggedIn) {
        account.onSkipUnsignedVoiceInteraction(currentAccount)
        return false
    }
    if (checkAssistantVoiceEntryMicrophonePermission(permission)) {
        when {
            request.useToggle -> dispatch.onToggleVoiceInput()
            request.forceNewTaskEntry -> dispatch.onStartNewTaskEntry()
            else -> dispatch.onApiMicClick()
        }
    } else {
        pending.onSavePendingVoiceInteraction(
            AssistantVoiceInteractionPendingState(
                accountId = currentAccount.currentAccountId,
                forceNewTaskEntry = request.forceNewTaskEntry,
                useToggle = request.useToggle
            )
        )
        permission.onLaunchVoiceInteractionPermission()
    }
    return true
}

internal fun isAssistantPendingVoiceEntryValid(
    reason: String,
    account: AssistantVoiceEntryAccountCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks
): Boolean {
    val currentAccount = account.accountProvider()
    val state = pending.pendingProvider()
    val valid = state.active &&
        currentAccount.currentAccountId.isNotBlank() &&
        state.accountId == currentAccount.currentAccountId &&
        currentAccount.mockLoggedIn
    if (!valid) {
        pending.onDropInvalidPending(
            AssistantVoiceEntryInvalidPendingResult(
                reason = reason,
                pendingActive = state.active,
                pendingAccountId = state.accountId,
                currentAccountId = currentAccount.currentAccountId,
                mockLoggedIn = currentAccount.mockLoggedIn
            )
        )
        pending.onClearPendingVoiceEntry()
    }
    return valid
}

internal fun openAssistantPendingVoiceEntry(
    account: AssistantVoiceEntryAccountCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks,
    flow: AssistantVoiceEntryFlowCallbacks
): Boolean {
    if (!isAssistantPendingVoiceEntryValid("open", account, pending)) return false
    if (flow.onBlockIdentityIncomplete()) {
        pending.onClearPendingVoiceEntry()
        return false
    }

    val state = pending.pendingProvider()
    if (state.resumeExisting) {
        flow.onOpenExistingSingleFlow()
        pending.onClearPendingVoiceEntry()
        return true
    }

    flow.onResetTaskConversationForNewEntry("open_pending_voice_entry")
    flow.onClearLocalTaskItemsForRequirementEntry()
    flow.onOpenNewSingleFlow(
        AssistantVoiceEntrySingleFlowPlan(
            initialCommand = state.initialCommand,
            startInVoice = state.startInVoice,
            forceNewVoiceEntryStart = shouldForceNewTaskVoiceEntryStart(
                startInVoice = state.startInVoice,
                resumeListeningOnly = false,
                resumeExisting = false,
                initialCommand = state.initialCommand
            ),
            initialSkillId = state.initialSkillId,
            initialSkillOpening = state.initialSkillOpening,
            selectedContact = state.selectedContact
        )
    )
    pending.onClearPendingVoiceEntry()
    return true
}

internal fun continueAssistantVoiceEntryAfterMicrophoneGranted(
    account: AssistantVoiceEntryAccountCallbacks,
    permission: AssistantVoiceEntryMicrophonePermissionCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks,
    flow: AssistantVoiceEntryFlowCallbacks
): Boolean {
    if (!isAssistantPendingVoiceEntryValid("permission_granted", account, pending)) return false
    permission.onMicrophonePermissionGrantedChange(true)
    if (flow.onBlockIdentityIncomplete()) {
        pending.onClearPendingVoiceEntry()
        return false
    }
    return openAssistantPendingVoiceEntry(account, pending, flow)
}

internal fun continueAssistantVoiceEntryAfterIdentityCompleted(
    account: AssistantVoiceEntryAccountCallbacks,
    permission: AssistantVoiceEntryMicrophonePermissionCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks,
    flow: AssistantVoiceEntryFlowCallbacks
): Boolean {
    if (!isAssistantPendingVoiceEntryValid("identity_completed", account, pending)) return false
    if (!checkAssistantVoiceEntryMicrophonePermission(permission)) {
        permission.onLaunchVoiceEntryPermission()
        return true
    }
    return continueAssistantVoiceEntryAfterMicrophoneGranted(account, permission, pending, flow)
}

internal fun startAssistantVoiceEntry(
    request: AssistantVoiceEntryStartRequest,
    account: AssistantVoiceEntryAccountCallbacks,
    permission: AssistantVoiceEntryMicrophonePermissionCallbacks,
    pending: AssistantVoiceEntryPendingCallbacks,
    flow: AssistantVoiceEntryFlowCallbacks
): Boolean {
    if (flow.onBlockOffline()) return false

    val currentAccount = account.accountProvider()
    if (currentAccount.currentAccountId.isBlank() || !currentAccount.mockLoggedIn) {
        account.onSkipUnsignedVoiceEntry(currentAccount)
        pending.onClearPendingVoiceEntry()
        return false
    }

    pending.onSavePendingVoiceEntry(
        AssistantPendingVoiceEntryState(
            initialCommand = request.initialCommand?.trim().orEmpty(),
            startInVoice = request.startWithVoice,
            resumeExisting = request.resumeExisting,
            active = true,
            accountId = currentAccount.currentAccountId,
            initialSkillId = request.initialSkillId?.trim()?.takeIf(String::isNotEmpty),
            initialSkillOpening = request.initialSkillOpening?.trim()?.takeIf(String::isNotEmpty),
            selectedContact = request.selectedContact
        )
    )
    if (flow.onBlockIdentityIncomplete()) return true
    if (!checkAssistantVoiceEntryMicrophonePermission(permission)) {
        permission.onLaunchVoiceEntryPermission()
        return true
    }
    return continueAssistantVoiceEntryAfterMicrophoneGranted(account, permission, pending, flow)
}
