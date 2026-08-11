package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext

internal class AssistantTaskEntryState(
    taskStarted: MutableState<Boolean>,
    taskUserText: MutableState<String>,
    taskTextDraft: MutableState<String>,
    aiThinking: MutableState<Boolean>,
    aiReplyVisible: MutableState<Boolean>,
    singleFlowInitialCommand: MutableState<String>,
    singleFlowSelectedContact: MutableState<SelectedContactTaskContext?>,
    singleFlowStartInVoice: MutableState<Boolean>,
    singleFlowResumeListeningOnly: MutableState<Boolean>,
    singleFlowForceNewVoiceEntryStart: MutableState<Boolean>,
    singleFlowEntryKey: MutableState<Long>,
    pendingVoiceEntryInitialCommand: MutableState<String>,
    pendingVoiceEntryStartInVoice: MutableState<Boolean>,
    pendingVoiceEntryResumeExisting: MutableState<Boolean>,
    pendingVoiceEntryActive: MutableState<Boolean>,
    pendingVoiceEntryAccountId: MutableState<String>,
    pendingVoiceEntryInitialSkillId: MutableState<String?> = mutableStateOf(null),
    pendingVoiceEntryInitialSkillOpening: MutableState<String?> = mutableStateOf(null),
    pendingVoiceEntrySelectedContact: MutableState<SelectedContactTaskContext?> = mutableStateOf(null),
    pendingVoiceInteractionPermissionActive: MutableState<Boolean>,
    pendingVoiceInteractionAccountId: MutableState<String>,
    pendingVoiceInteractionForceNewTaskEntry: MutableState<Boolean>,
    pendingVoiceInteractionUseToggle: MutableState<Boolean>,
    voiceEntryPermissionGrantedSignal: MutableState<Long>,
    selectedRestaurantId: MutableState<String?>,
    restaurantConfirmed: MutableState<Boolean>,
    confirmingRestaurantId: MutableState<String?>,
    val selectedFallbackIds: SnapshotStateList<String>,
    val requiredFallbackIds: SnapshotStateList<String>,
    fallbackConfirmed: MutableState<Boolean>,
    confirmingFallbackId: MutableState<String?>,
    confirmAttachmentUploaded: MutableState<Boolean>,
    aiCallSeconds: MutableState<Int>
) {
    var taskStarted by taskStarted
    var taskUserText by taskUserText
    var taskTextDraft by taskTextDraft
    var aiThinking by aiThinking
    var aiReplyVisible by aiReplyVisible
    var singleFlowInitialCommand by singleFlowInitialCommand
    var singleFlowSelectedContact by singleFlowSelectedContact
    var singleFlowStartInVoice by singleFlowStartInVoice
    var singleFlowResumeListeningOnly by singleFlowResumeListeningOnly
    var singleFlowForceNewVoiceEntryStart by singleFlowForceNewVoiceEntryStart
    var singleFlowEntryKey by singleFlowEntryKey
    var pendingVoiceEntryInitialCommand by pendingVoiceEntryInitialCommand
    var pendingVoiceEntryStartInVoice by pendingVoiceEntryStartInVoice
    var pendingVoiceEntryResumeExisting by pendingVoiceEntryResumeExisting
    var pendingVoiceEntryActive by pendingVoiceEntryActive
    var pendingVoiceEntryAccountId by pendingVoiceEntryAccountId
    var pendingVoiceEntryInitialSkillId by pendingVoiceEntryInitialSkillId
    var pendingVoiceEntryInitialSkillOpening by pendingVoiceEntryInitialSkillOpening
    var pendingVoiceEntrySelectedContact by pendingVoiceEntrySelectedContact
    var pendingVoiceInteractionPermissionActive by pendingVoiceInteractionPermissionActive
    var pendingVoiceInteractionAccountId by pendingVoiceInteractionAccountId
    var pendingVoiceInteractionForceNewTaskEntry by pendingVoiceInteractionForceNewTaskEntry
    var pendingVoiceInteractionUseToggle by pendingVoiceInteractionUseToggle
    var voiceEntryPermissionGrantedSignal by voiceEntryPermissionGrantedSignal
    var selectedRestaurantId by selectedRestaurantId
    var restaurantConfirmed by restaurantConfirmed
    var confirmingRestaurantId by confirmingRestaurantId
    var fallbackConfirmed by fallbackConfirmed
    var confirmingFallbackId by confirmingFallbackId
    var confirmAttachmentUploaded by confirmAttachmentUploaded
    var aiCallSeconds by aiCallSeconds

    fun bumpSingleFlowEntry() {
        singleFlowEntryKey += 1L
    }

    fun invalidatePendingSingleFlowEntry(): Long {
        singleFlowSelectedContact = null
        singleFlowStartInVoice = false
        singleFlowResumeListeningOnly = false
        singleFlowForceNewVoiceEntryStart = false
        bumpSingleFlowEntry()
        return singleFlowEntryKey
    }

    fun clearRequirementSelectionState() {
        selectedRestaurantId = null
        restaurantConfirmed = false
        confirmingRestaurantId = null
        selectedFallbackIds.clear()
        requiredFallbackIds.clear()
        fallbackConfirmed = false
        confirmingFallbackId = null
        confirmAttachmentUploaded = false
    }

    fun clearLocalTaskItemsForRequirementEntry() {
        taskUserText = ""
        taskTextDraft = ""
        singleFlowInitialCommand = ""
        singleFlowSelectedContact = null
        singleFlowStartInVoice = false
        singleFlowResumeListeningOnly = false
        singleFlowForceNewVoiceEntryStart = false
        taskStarted = false
        aiThinking = false
        aiReplyVisible = false
        aiCallSeconds = 0
        clearRequirementSelectionState()
    }

    fun consumeSingleFlowSelectedContact(): SelectedContactTaskContext? {
        val selectedContact = singleFlowSelectedContact
        singleFlowSelectedContact = null
        return selectedContact
    }

    fun clearPendingVoiceEntryState(onClearVoiceCloneGuide: () -> Unit) {
        pendingVoiceEntryInitialCommand = ""
        pendingVoiceEntryStartInVoice = true
        pendingVoiceEntryResumeExisting = false
        pendingVoiceEntryActive = false
        pendingVoiceEntryAccountId = ""
        pendingVoiceEntryInitialSkillId = null
        pendingVoiceEntryInitialSkillOpening = null
        pendingVoiceEntrySelectedContact = null
        pendingVoiceInteractionPermissionActive = false
        pendingVoiceInteractionAccountId = ""
        pendingVoiceInteractionForceNewTaskEntry = false
        pendingVoiceInteractionUseToggle = false
        voiceEntryPermissionGrantedSignal = 0L
        onClearVoiceCloneGuide()
    }
}

@Composable
internal fun rememberAssistantTaskEntryState(): AssistantTaskEntryState =
    AssistantTaskEntryState(
        taskStarted = rememberSaveable { mutableStateOf(false) },
        taskUserText = rememberSaveable { mutableStateOf("") },
        taskTextDraft = rememberSaveable { mutableStateOf("") },
        aiThinking = rememberSaveable { mutableStateOf(false) },
        aiReplyVisible = rememberSaveable { mutableStateOf(false) },
        singleFlowInitialCommand = rememberSaveable { mutableStateOf("") },
        singleFlowSelectedContact = remember { mutableStateOf(null) },
        singleFlowStartInVoice = rememberSaveable { mutableStateOf(false) },
        singleFlowResumeListeningOnly = rememberSaveable { mutableStateOf(false) },
        singleFlowForceNewVoiceEntryStart = rememberSaveable { mutableStateOf(false) },
        singleFlowEntryKey = rememberSaveable { mutableStateOf(0L) },
        pendingVoiceEntryInitialCommand = rememberSaveable { mutableStateOf("") },
        pendingVoiceEntryStartInVoice = rememberSaveable { mutableStateOf(true) },
        pendingVoiceEntryResumeExisting = rememberSaveable { mutableStateOf(false) },
        pendingVoiceEntryActive = remember { mutableStateOf(false) },
        pendingVoiceEntryAccountId = remember { mutableStateOf("") },
        pendingVoiceEntryInitialSkillId = remember { mutableStateOf<String?>(null) },
        pendingVoiceEntryInitialSkillOpening = remember { mutableStateOf<String?>(null) },
        pendingVoiceEntrySelectedContact = remember { mutableStateOf<SelectedContactTaskContext?>(null) },
        pendingVoiceInteractionPermissionActive = remember { mutableStateOf(false) },
        pendingVoiceInteractionAccountId = remember { mutableStateOf("") },
        pendingVoiceInteractionForceNewTaskEntry = remember { mutableStateOf(false) },
        pendingVoiceInteractionUseToggle = remember { mutableStateOf(false) },
        voiceEntryPermissionGrantedSignal = remember { mutableStateOf(0L) },
        selectedRestaurantId = rememberSaveable { mutableStateOf<String?>(null) },
        restaurantConfirmed = rememberSaveable { mutableStateOf(false) },
        confirmingRestaurantId = rememberSaveable { mutableStateOf<String?>(null) },
        selectedFallbackIds = remember { mutableStateListOf<String>() },
        requiredFallbackIds = remember { mutableStateListOf<String>() },
        fallbackConfirmed = rememberSaveable { mutableStateOf(false) },
        confirmingFallbackId = rememberSaveable { mutableStateOf<String?>(null) },
        confirmAttachmentUploaded = rememberSaveable { mutableStateOf(false) },
        aiCallSeconds = rememberSaveable { mutableStateOf(0) }
    )
