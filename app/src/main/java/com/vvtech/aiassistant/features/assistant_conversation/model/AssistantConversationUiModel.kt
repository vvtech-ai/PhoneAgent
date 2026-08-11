package com.vvtech.aiassistant.features.assistant_conversation.model

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.DetailSupplementPageData
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceRole

data class AssistantSessionUiState(
    val sessionId: String? = null,
    val taskId: String? = null,
    val sceneType: String = "GENERAL"
)

data class AssistantMessageListUiState(
    val messages: List<AssistantConversationMessageUi> = emptyList(),
    val conversations: List<ConversationListItem> = emptyList(),
    val conversationsLoading: Boolean = false,
    val conversationsError: String? = null,
    val liveUserTranscript: String? = null,
    val liveAssistantTranscript: String? = null,
    val processingTurn: Boolean = false
)

data class AssistantConversationMessageUi(
    val role: AssistantConversationMessageRole,
    val text: String,
    val status: String,
    val thinking: String? = null,
    val toolCalls: List<ToolCallInfo>? = null,
    val streaming: Boolean = false
)

enum class AssistantConversationMessageRole {
    Assistant,
    User
}

fun VoiceRole.toAssistantConversationMessageRole(): AssistantConversationMessageRole {
    return when (this) {
        VoiceRole.Assistant -> AssistantConversationMessageRole.Assistant
        VoiceRole.User -> AssistantConversationMessageRole.User
    }
}

data class AssistantVoiceUiState(
    val connecting: Boolean = false,
    val active: Boolean = false,
    val manuallyPaused: Boolean = false,
    val backgroundPaused: Boolean = false,
    val listening: Boolean = false,
    val asrListening: Boolean = false,
    val asrPartialText: String? = null,
    val ttsPlaying: Boolean = false,
    val localTtsSpeaking: Boolean = false
)

data class AssistantAgentInteractionUiState(
    val options: OptionsPayload? = null,
    val questions: AskQuestionsPayload? = null,
    val permissionRequest: PermissionRequestPayload? = null,
    val documentRequest: DocumentImportRequestPayload? = null,
    val documentImporting: Boolean = false,
    val pendingToolCallId: String? = null,
    val callSpec: CallSpecPayload? = null,
    val callResult: CallResultPayload? = null,
    val lookupContactPhone: String? = null,
    val lookupContactInFlight: Boolean = false,
    val lookupDeviceContactsInFlight: Boolean = false,
    val deviceContactSelection: DeviceContactSelectionUiState? = null
)

data class AssistantCallUiState(
    val currentCallId: String? = null,
    val showAiCallPage: Boolean = false,
    val mode: CallUiMode = CallUiMode.Ai,
    val handoffInFlight: Boolean = false,
    val callPage: CallPageData? = null
)

data class AssistantTaskUiState(
    val taskStatus: String = "INIT",
    val unresolvedTaskErrorStatus: String? = null,
    val taskErrorRecoveryInProgress: Boolean = false,
    val summary: SummaryData? = null,
    val selectionSheet: SelectionSheetData? = null,
    val detailSupplement: DetailSupplementPageData? = null
)

data class AssistantLocationUiState(
    val available: Boolean = false,
    val displayText: String = ""
)
