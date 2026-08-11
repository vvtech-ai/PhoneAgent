package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.logging.AppFileLogger

internal data class AssistantVoiceEntryRootActionDeps(
    val context: Context,
    val taskEntry: AssistantTaskEntryState,
    val mockLoggedInProvider: () -> Boolean,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onLaunchVoiceEntryPermission: () -> Unit,
    val onLaunchVoiceInteractionPermission: () -> Unit,
    val onClearPendingVoiceEntryState: () -> Unit
)

internal data class AssistantVoiceEntryRootFlowCallbacks(
    val onBlockOffline: () -> Boolean,
    val onBlockIdentityIncomplete: () -> Boolean,
    val onResetTaskConversationForNewEntry: (String) -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onOpenExistingSingleFlow: () -> Unit,
    val onOpenNewSingleFlow: (AssistantVoiceEntrySingleFlowPlan) -> Unit
)

internal data class AssistantVoiceEntryRootDispatchCallbacks(
    val onToggleVoiceInput: () -> Unit,
    val onStartNewTaskEntry: () -> Unit,
    val onApiMicClick: () -> Unit
)

internal class AssistantVoiceEntryRootActions(
    private val deps: AssistantVoiceEntryRootActionDeps,
    private val flowCallbacks: AssistantVoiceEntryRootFlowCallbacks,
    private val dispatchCallbacks: AssistantVoiceEntryRootDispatchCallbacks
) {
    private val accountCallbacks = AssistantVoiceEntryAccountCallbacks(
        accountProvider = {
            AssistantVoicePermissionAccountState(
                currentAccountId = AccountIdentityProvider.accountId,
                mockLoggedIn = deps.mockLoggedInProvider()
            )
        },
        onSkipUnsignedVoiceInteraction = { account ->
            AppFileLogger.w(
                VoiceEntryLogTag,
                "skip voice interaction without signed account account=${account.currentAccountId} loggedIn=${account.mockLoggedIn}"
            )
        },
        onSkipUnsignedVoiceEntry = { account ->
            AppFileLogger.w(
                VoiceEntryLogTag,
                "skip voice entry without signed account account=${account.currentAccountId} loggedIn=${account.mockLoggedIn}"
            )
        }
    )

    private val permissionCallbacks = AssistantVoiceEntryMicrophonePermissionCallbacks(
        hasMicrophonePermission = {
            ContextCompat.checkSelfPermission(
                deps.context,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        },
        onMicrophonePermissionGrantedChange = deps.onMicrophonePermissionGrantedChange,
        onLaunchVoiceEntryPermission = deps.onLaunchVoiceEntryPermission,
        onLaunchVoiceInteractionPermission = deps.onLaunchVoiceInteractionPermission
    )

    private val pendingCallbacks = AssistantVoiceEntryPendingCallbacks(
        pendingProvider = {
            AssistantPendingVoiceEntryState(
                initialCommand = deps.taskEntry.pendingVoiceEntryInitialCommand,
                startInVoice = deps.taskEntry.pendingVoiceEntryStartInVoice,
                resumeExisting = deps.taskEntry.pendingVoiceEntryResumeExisting,
                active = deps.taskEntry.pendingVoiceEntryActive,
                accountId = deps.taskEntry.pendingVoiceEntryAccountId,
                initialSkillId = deps.taskEntry.pendingVoiceEntryInitialSkillId,
                initialSkillOpening = deps.taskEntry.pendingVoiceEntryInitialSkillOpening,
                selectedContact = deps.taskEntry.pendingVoiceEntrySelectedContact
            )
        },
        onSavePendingVoiceEntry = { pending ->
            deps.taskEntry.pendingVoiceEntryInitialCommand = pending.initialCommand
            deps.taskEntry.pendingVoiceEntryStartInVoice = pending.startInVoice
            deps.taskEntry.pendingVoiceEntryResumeExisting = pending.resumeExisting
            deps.taskEntry.pendingVoiceEntryActive = pending.active
            deps.taskEntry.pendingVoiceEntryAccountId = pending.accountId
            deps.taskEntry.pendingVoiceEntryInitialSkillId = pending.initialSkillId
            deps.taskEntry.pendingVoiceEntryInitialSkillOpening = pending.initialSkillOpening
            deps.taskEntry.pendingVoiceEntrySelectedContact = pending.selectedContact
        },
        onClearPendingVoiceEntry = deps.onClearPendingVoiceEntryState,
        onDropInvalidPending = { invalid ->
            AppFileLogger.w(
                VoiceEntryLogTag,
                "drop invalid pending voice entry reason=${invalid.reason} pending=${invalid.pendingActive} " +
                    "pendingAccount=${invalid.pendingAccountId} currentAccount=${invalid.currentAccountId} loggedIn=${invalid.mockLoggedIn}"
            )
        },
        onSavePendingVoiceInteraction = { pending ->
            deps.taskEntry.pendingVoiceInteractionPermissionActive = true
            deps.taskEntry.pendingVoiceInteractionAccountId = pending.accountId
            deps.taskEntry.pendingVoiceInteractionForceNewTaskEntry = pending.forceNewTaskEntry
            deps.taskEntry.pendingVoiceInteractionUseToggle = pending.useToggle
        }
    )

    private val flow = AssistantVoiceEntryFlowCallbacks(
        onBlockOffline = flowCallbacks.onBlockOffline,
        onBlockIdentityIncomplete = flowCallbacks.onBlockIdentityIncomplete,
        onResetTaskConversationForNewEntry = flowCallbacks.onResetTaskConversationForNewEntry,
        onClearLocalTaskItemsForRequirementEntry = flowCallbacks.onClearLocalTaskItemsForRequirementEntry,
        onOpenExistingSingleFlow = flowCallbacks.onOpenExistingSingleFlow,
        onOpenNewSingleFlow = flowCallbacks.onOpenNewSingleFlow
    )

    private val dispatch = AssistantVoiceInteractionDispatchCallbacks(
        onToggleVoiceInput = dispatchCallbacks.onToggleVoiceInput,
        onStartNewTaskEntry = dispatchCallbacks.onStartNewTaskEntry,
        onApiMicClick = dispatchCallbacks.onApiMicClick
    )

    fun hasMicrophonePermissionForVoiceEntry(): Boolean =
        checkAssistantVoiceEntryMicrophonePermission(permissionCallbacks)

    fun startVoiceInteractionWithPermission(
        forceNewTaskEntry: Boolean = false,
        useToggle: Boolean = false
    ): Boolean = startAssistantVoiceInteractionWithPermission(
        request = AssistantVoiceInteractionStartRequest(
            forceNewTaskEntry = forceNewTaskEntry,
            useToggle = useToggle
        ),
        account = accountCallbacks,
        permission = permissionCallbacks,
        pending = pendingCallbacks,
        dispatch = dispatch
    )

    fun hasValidPendingVoiceEntry(reason: String): Boolean = isAssistantPendingVoiceEntryValid(
        reason = reason,
        account = accountCallbacks,
        pending = pendingCallbacks
    )

    fun openPendingVoiceEntry(): Boolean = openAssistantPendingVoiceEntry(
        account = accountCallbacks,
        pending = pendingCallbacks,
        flow = flow
    )

    fun continueVoiceEntryAfterMicrophoneGranted(): Boolean = continueAssistantVoiceEntryAfterMicrophoneGranted(
        account = accountCallbacks,
        permission = permissionCallbacks,
        pending = pendingCallbacks,
        flow = flow
    )

    fun continueVoiceEntryAfterIdentityCompleted(): Boolean =
        continueAssistantVoiceEntryAfterIdentityCompleted(
            account = accountCallbacks,
            permission = permissionCallbacks,
            pending = pendingCallbacks,
            flow = flow
        )

    fun cancelPendingVoiceEntry() {
        deps.onClearPendingVoiceEntryState()
    }

    fun startVoiceEntry(
        initialCommand: String? = null,
        startWithVoice: Boolean = true,
        resumeExisting: Boolean,
        initialSkillId: String? = null,
        initialSkillOpening: String? = null,
        selectedContact: SelectedContactTaskContext? = null
    ): Boolean = startAssistantVoiceEntry(
        request = AssistantVoiceEntryStartRequest(
            initialCommand = initialCommand,
            startWithVoice = startWithVoice,
            resumeExisting = resumeExisting,
            initialSkillId = initialSkillId,
            initialSkillOpening = initialSkillOpening,
            selectedContact = selectedContact
        ),
        account = accountCallbacks,
        permission = permissionCallbacks,
        pending = pendingCallbacks,
        flow = flow
    )
}

private const val VoiceEntryLogTag = "AssistantRootScreen"
