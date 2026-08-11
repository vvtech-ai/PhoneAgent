package com.vvtech.aiassistant.features.assistant

import android.net.Uri
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUiStateReducer
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrCommitInput
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrCommitResult
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrHistoryAttachment
import kotlinx.coroutines.flow.update

fun AssistantViewModel.onAgentPermissionResult(
    permissionKey: String,
    androidPermission: String?,
    status: String,
    granted: Boolean,
    message: String? = null
) = agentStreamHandler.onAgentPermissionResult(
    permissionKey = permissionKey,
    androidPermission = androidPermission,
    status = status,
    granted = granted,
    message = message
)

fun AssistantViewModel.onAgentDocumentPickerCancelled() =
    agentDocumentActionHandler.onDocumentPickerCancelled()

fun AssistantViewModel.onAgentLookupContactResult(payload: Map<String, Any?>) =
    agentStreamHandler.onAgentLookupContactResult(payload)

fun AssistantViewModel.onAgentLookupDeviceContactsResolved(
    results: List<Map<String, Any?>>,
    echoText: String? = null,
    pendingSelection: DeviceContactSelectionUiState? = null
) = agentStreamHandler.onAgentLookupDeviceContactsResolved(results, echoText, pendingSelection)

fun AssistantViewModel.onAgentDeviceContactSelectionConfirm(
    selectedByName: Map<String, DeviceContactSelectionCandidateUi>
) = agentStreamHandler.onAgentDeviceContactSelectionConfirm(selectedByName)

fun AssistantViewModel.onAgentDeviceContactSelectionCancel() =
    agentStreamHandler.onAgentDeviceContactSelectionCancel()

fun AssistantViewModel.setIdentityInitOverlayVisible(visible: Boolean) {
    internalUiState.update {
        AssistantUiStateReducer.setIdentityInitOverlayVisible(it, visible)
    }
}

fun AssistantViewModel.onAgentDocumentPicked(uri: Uri) =
    agentDocumentActionHandler.onDocumentPicked(uri)

internal fun AssistantViewModel.ensureAgentSession(): String =
    agentStreamHandler.ensureAgentSession()

internal fun AssistantViewModel.pendingInitialOpeningForSession(sessionId: String): String? =
    AgentInitialSkillLaunchStore.peekPresentedOpeningForSession(sessionId)

internal suspend fun AssistantViewModel.commitPureVoiceOcrAttachment(
    input: PureVoiceOcrCommitInput
): PureVoiceOcrCommitResult = pureVoiceOcrAttachmentHandler.commit(input)

internal suspend fun AssistantViewModel.loadPureVoiceOcrHistoryImage(
    attachment: PureVoiceOcrHistoryAttachment
): Uri = pureVoiceOcrAttachmentHandler.loadHistoryImage(attachment)

internal fun AssistantViewModel.startStreamingAgentTurn(
    sessionId: String,
    message: String,
    pendingToolCallId: String?,
    selectedContact: SelectedContactTaskContext? = null,
    supersedesCommandId: String? = null,
) = agentStreamHandler.startStreamingAgentTurn(
    sessionId,
    message,
    pendingToolCallId,
    selectedContact,
    supersedesCommandId,
)

internal fun AssistantViewModel.appendStreamingAssistantStep(): Int =
    agentStreamHandler.appendStreamingAssistantStep()

internal fun AssistantViewModel.mutateStep(
    index: Int,
    mutator: (ClarificationStep) -> ClarificationStep
) = agentStreamHandler.mutateStep(index, mutator)

internal fun AssistantViewModel.finalizeStreamingStep(index: Int) =
    agentStreamHandler.finalizeStreamingStep(index)

internal fun AssistantViewModel.applyStreamEvent(stepIndex: Int, ev: AgentStreamEvent) =
    agentStreamHandler.applyStreamEvent(stepIndex, ev)

internal fun AssistantViewModel.handleAgentResponse(response: AgentChatResponse) =
    agentStreamHandler.handleAgentResponse(response)

internal fun AssistantViewModel.applyAgentResponseState(response: AgentChatResponse) =
    agentStreamHandler.applyAgentResponseState(response)

fun AssistantViewModel.onAgentOptionSelect(optionId: String) =
    agentStreamHandler.onAgentOptionSelect(optionId)

fun AssistantViewModel.onAgentAnswerSubmit(answers: Map<String, Any>) =
    agentStreamHandler.onAgentAnswerSubmit(answers)

fun AssistantViewModel.onAgentCallConfirm() =
    agentStreamHandler.onAgentCallConfirm()

fun AssistantViewModel.onAgentCallEdit() =
    agentStreamHandler.onAgentCallEdit()
