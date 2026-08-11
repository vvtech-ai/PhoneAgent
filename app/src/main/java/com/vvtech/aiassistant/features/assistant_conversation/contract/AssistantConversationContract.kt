package com.vvtech.aiassistant.features.assistant_conversation.contract

import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantAgentInteractionUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantCallUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantLocationUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantMessageListUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantSessionUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantTaskUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantVoiceUiState

data class AssistantConversationUiState(
    val session: AssistantSessionUiState = AssistantSessionUiState(),
    val conversation: AssistantMessageListUiState = AssistantMessageListUiState(),
    val voice: AssistantVoiceUiState = AssistantVoiceUiState(),
    val agent: AssistantAgentInteractionUiState = AssistantAgentInteractionUiState(),
    val call: AssistantCallUiState = AssistantCallUiState(),
    val task: AssistantTaskUiState = AssistantTaskUiState(),
    val location: AssistantLocationUiState = AssistantLocationUiState(),
    val loading: Boolean = false,
    val errorMessage: String? = null
)

sealed interface AssistantConversationAction {
    object Initialize : AssistantConversationAction
    object LoadConversations : AssistantConversationAction
    data class ResumeConversation(val sessionId: String) : AssistantConversationAction

    data class SubmitText(val text: String) : AssistantConversationAction
    object StartVoice : AssistantConversationAction
    object StartVoiceForNewTask : AssistantConversationAction
    data class StopVoice(val reason: String) : AssistantConversationAction
    object ToggleMic : AssistantConversationAction
    object InterruptTts : AssistantConversationAction

    data class SubmitAgentAnswers(val answers: Map<String, String>) : AssistantConversationAction
    data class SelectAgentOption(val optionId: String) : AssistantConversationAction
    data class SubmitPermissionResult(val granted: Boolean) : AssistantConversationAction
    object CancelDocumentPick : AssistantConversationAction
    data class ConfirmDeviceContact(val phoneNumber: String) : AssistantConversationAction
    object CancelDeviceContactSelection : AssistantConversationAction
}

sealed interface AssistantConversationEffect {
    data class RequestPermission(val permission: String, val reason: String) : AssistantConversationEffect
    data class OpenDocumentPicker(val mimeTypes: List<String>) : AssistantConversationEffect
    data class ShowToast(val message: String) : AssistantConversationEffect
    data class NavigateToConversation(val sessionId: String?) : AssistantConversationEffect
    object OpenSettings : AssistantConversationEffect
}
