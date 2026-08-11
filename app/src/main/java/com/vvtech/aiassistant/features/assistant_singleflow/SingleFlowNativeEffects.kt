package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.PersonalInfoEntry
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceUiCommandType
import com.vvtech.aiassistant.features.assistant.sfDetailIdsFromSummary
import com.vvtech.aiassistant.features.assistant.sfRealFlowProgressSignature
import com.vvtech.aiassistant.features.assistant.sfRealRestaurantStage
import com.vvtech.aiassistant.features.assistant.sfSummaryVoiceSignature
import com.vvtech.aiassistant.features.assistant.sfVoiceDetailPromptForScene
import com.vvtech.aiassistant.features.assistant.toEffectiveTaskContact
import kotlinx.coroutines.delay

internal data class SingleFlowNativeRuntimeEffectsArgs(
    val state: SingleFlowNativeStateHolder,
    val assistantState: Index9AssistantUiState?,
    val savedContacts: List<PersonalInfoEntry>
)

internal data class SingleFlowNativeRuntimeEffectCallbacks(
    val onBack: (() -> Unit)?,
    val onCompleteDetailSupplement: ((EffectiveTaskContact, String) -> Unit)?,
    val onBeginVoiceContactReentry: ((String) -> Unit)?,
    val onBeginVoiceDefaultContactConfirmation: ((String) -> Unit)?,
    val onBeginVoiceDetailSupplementPrompt: ((String) -> Unit)?,
    val onBeginVoiceSummaryConfirmation: ((SummaryData) -> Unit)?,
    val onSpeakVoicePrompt: ((String) -> Unit)?,
    val onVoiceContactCaptured: ((EffectiveTaskContact) -> Unit)?
)

@Composable
internal fun SingleFlowNativeRuntimeEffects(
    args: SingleFlowNativeRuntimeEffectsArgs,
    callbacks: SingleFlowNativeRuntimeEffectCallbacks
) {
    val state = args.state
    val assistantState = args.assistantState
    val savedContacts = args.savedContacts
    val inputMode = state.inputMode
    val supplementContact = state.supplementContact
    val manualContactMode = state.manualContactMode
    val preferredSavedContact = savedContacts.firstOrNull { it.isDefault } ?: savedContacts.firstOrNull()
    val realFlowEnabled = assistantState != null
    val realFlowProgressSignature = sfRealFlowProgressSignature(assistantState)

    LaunchedEffect(assistantState?.detailSupplement?.taskId, savedContacts.size, inputMode) {
        val taskId = assistantState?.detailSupplement?.taskId
        if (taskId != state.detailSupplementTaskId) {
            state.detailSupplementTaskId = taskId
            state.supplementContact = null
            state.manualContactMode = taskId != null && savedContacts.isEmpty()
            state.contactInputError = null
            state.selectedDetailQuestionIds.clear()
            state.voiceContactPromptTaskId = null
            state.voiceDetailPromptTaskId = null
            state.voiceSummaryPromptSignature = ""
            state.handledVoiceUiCommandEventId = 0L
        } else if (taskId != null && savedContacts.isEmpty() && state.supplementContact == null) {
            state.manualContactMode = true
        }
        if (
            taskId != null &&
            inputMode == SfInputMode.Voice &&
            state.supplementContact == null &&
            state.voiceContactPromptTaskId != taskId
        ) {
            state.voiceContactPromptTaskId = taskId
            if (savedContacts.isEmpty()) {
                state.manualContactMode = true
                callbacks.onBeginVoiceContactReentry?.invoke("请补充预订人信息，包括称呼和手机号码")
            } else if (!state.manualContactMode) {
                val prompt = if (preferredSavedContact != null && preferredSavedContact.phone.length >= 4) {
                    "要留你尾号${preferredSavedContact.phone.takeLast(4)}的号码吗？"
                } else {
                    "请确认预订人信息"
                }
                if (callbacks.onBeginVoiceDefaultContactConfirmation != null) {
                    callbacks.onBeginVoiceDefaultContactConfirmation.invoke(prompt)
                } else {
                    callbacks.onSpeakVoicePrompt?.invoke(prompt)
                }
            }
        }
    }

    LaunchedEffect(assistantState?.voiceContactCapture?.eventId, assistantState?.detailSupplement?.taskId) {
        val capture = assistantState?.voiceContactCapture ?: return@LaunchedEffect
        val contact = capture.completedContact ?: return@LaunchedEffect
        val taskId = assistantState.detailSupplement?.taskId ?: return@LaunchedEffect
        if (capture.taskId == taskId && capture.eventId != 0L && capture.eventId != state.handledVoiceContactEventId) {
            state.handledVoiceContactEventId = capture.eventId
            state.supplementContact = contact
            state.manualContactMode = false
            state.contactInputError = null
            state.selectedDetailQuestionIds.clear()
            callbacks.onVoiceContactCaptured?.invoke(contact)
        }
    }

    LaunchedEffect(
        assistantState?.voiceUiCommand?.eventId,
        assistantState?.detailSupplement?.taskId,
        assistantState?.taskId,
        preferredSavedContact?.id,
        manualContactMode,
        supplementContact,
        inputMode
    ) {
        val command = assistantState?.voiceUiCommand ?: return@LaunchedEffect
        if (command.eventId == 0L || command.eventId == state.handledVoiceUiCommandEventId) {
            return@LaunchedEffect
        }
        when (command.type) {
            VoiceUiCommandType.ReturnHome -> {
                state.handledVoiceUiCommandEventId = command.eventId
                callbacks.onBack?.invoke()
            }

            VoiceUiCommandType.ConfirmDefaultContact -> {
                val taskId = assistantState.detailSupplement?.taskId ?: return@LaunchedEffect
                if (command.taskId != taskId) return@LaunchedEffect
                if (preferredSavedContact != null && !state.manualContactMode && state.supplementContact == null) {
                    state.handledVoiceUiCommandEventId = command.eventId
                    state.confirmSupplementContact(preferredSavedContact.toEffectiveTaskContact())
                }
            }

            VoiceUiCommandType.CompleteDetailSupplement -> {
                val taskId = assistantState.detailSupplement?.taskId ?: return@LaunchedEffect
                val contact = state.supplementContact ?: return@LaunchedEffect
                if (command.taskId != taskId) return@LaunchedEffect
                state.handledVoiceUiCommandEventId = command.eventId
                state.selectedDetailQuestionIds.clear()
                state.selectedDetailQuestionIds.addAll(sfDetailIdsFromSummary(command.detailSummaryText))
                callbacks.onCompleteDetailSupplement?.invoke(contact, command.detailSummaryText)
            }
        }
    }

    LaunchedEffect(
        assistantState?.detailSupplement?.taskId,
        assistantState?.detailSupplement?.loading,
        supplementContact,
        inputMode,
        state.voiceDetailPromptTaskId
    ) {
        val supplement = assistantState?.detailSupplement ?: return@LaunchedEffect
        if (
            inputMode == SfInputMode.Voice &&
            supplement.sceneType in setOf("FOOD_ORDERING", "HOTEL_BOOKING") &&
            supplementContact != null &&
            !supplement.loading &&
            state.voiceDetailPromptTaskId != supplement.taskId
        ) {
            state.voiceDetailPromptTaskId = supplement.taskId
            callbacks.onBeginVoiceDetailSupplementPrompt?.invoke(sfVoiceDetailPromptForScene(supplement.sceneType))
        }
    }

    LaunchedEffect(
        assistantState?.taskId,
        assistantState?.summary,
        assistantState?.detailSupplement,
        assistantState?.selectionSheet,
        assistantState?.processingTurn,
        inputMode,
        state.voiceSummaryPromptSignature
    ) {
        val activeState = assistantState ?: return@LaunchedEffect
        val summary = activeState.summary ?: return@LaunchedEffect
        if (
            inputMode == SfInputMode.Voice &&
            activeState.detailSupplement == null &&
            activeState.selectionSheet == null &&
            !activeState.processingTurn &&
            !activeState.showAiCallPage
        ) {
            val signature = sfSummaryVoiceSignature(activeState.taskId, summary)
            if (signature.isNotBlank() && signature != state.voiceSummaryPromptSignature) {
                state.voiceSummaryPromptSignature = signature
                callbacks.onBeginVoiceSummaryConfirmation?.invoke(summary)
            }
        }
    }

    LaunchedEffect(
        assistantState?.taskId,
        assistantState?.selectionSheet,
        assistantState?.summary,
        assistantState?.detailSupplement,
        assistantState?.showAiCallPage,
        assistantState?.callPageData?.status,
        assistantState?.callPageData?.transcript?.size,
        assistantState?.callPageData?.transcript?.lastOrNull()?.text,
        assistantState?.clarificationSteps?.size,
        assistantState?.clarificationSteps?.lastOrNull()?.text,
        realFlowProgressSignature,
        assistantState?.taskStatus,
        assistantState?.processingTurn
    ) {
        assistantState?.let { activeState ->
            state.stage = sfRealRestaurantStage(activeState)
        }
    }

    val realStepCount = assistantState?.clarificationSteps?.size ?: 0
    LaunchedEffect(state.threadItems.size, realStepCount) {
        if (realFlowEnabled && realStepCount > 0) {
            state.listState.animateScrollToItem(realStepCount - 1)
        } else if (state.threadItems.isNotEmpty()) {
            state.listState.animateScrollToItem(state.threadItems.lastIndex)
        }
    }

    LaunchedEffect(state.callVisible) {
        if (state.callVisible) {
            while (state.callVisible) {
                delay(1000)
                state.callSeconds += 1
            }
        }
    }

    LaunchedEffect(state.callTranscripts.size, state.callVisible) {
        if (state.callVisible && state.callTranscripts.isNotEmpty()) {
            state.callListState.animateScrollToItem(state.callTranscripts.lastIndex)
        }
    }
}
