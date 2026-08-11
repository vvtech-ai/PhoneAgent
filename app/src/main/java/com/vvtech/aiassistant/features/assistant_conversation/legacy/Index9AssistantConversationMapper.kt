package com.vvtech.aiassistant.features.assistant_conversation.legacy

import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantAgentInteractionUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantCallUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantConversationMessageUi
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantLocationUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantMessageListUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantSessionUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantTaskUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantVoiceUiState
import com.vvtech.aiassistant.features.assistant_conversation.model.toAssistantConversationMessageRole
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

fun Index9AssistantUiState.toAssistantConversationUiState(
    sessionId: String?,
    conversations: List<ConversationListItem>,
    conversationLoading: Boolean,
    conversationError: String?
): AssistantConversationUiState {
    return AssistantConversationUiState(
        session = AssistantSessionUiState(
            sessionId = sessionId,
            taskId = taskId,
            sceneType = sceneType
        ),
        conversation = AssistantMessageListUiState(
            messages = clarificationSteps.map { step ->
                AssistantConversationMessageUi(
                    role = step.role.toAssistantConversationMessageRole(),
                    text = step.text,
                    status = step.status,
                    thinking = step.thinking,
                    toolCalls = step.toolCalls,
                    streaming = step.streaming
                )
            },
            conversations = conversations,
            conversationsLoading = conversationLoading,
            conversationsError = conversationError,
            liveUserTranscript = liveUserTranscript,
            liveAssistantTranscript = liveAssistantTranscript,
            processingTurn = processingTurn
        ),
        voice = AssistantVoiceUiState(
            connecting = voiceConnecting,
            active = voiceActive,
            manuallyPaused = voiceManuallyPaused,
            backgroundPaused = voiceBackgroundPaused,
            listening = listening,
            asrListening = apiAsrListening,
            asrPartialText = apiAsrPartialText,
            ttsPlaying = apiTtsPlaying,
            localTtsSpeaking = localTtsSpeaking
        ),
        agent = AssistantAgentInteractionUiState(
            options = agentOptions,
            questions = agentQuestions,
            permissionRequest = agentPermissionRequest,
            documentRequest = agentDocumentRequest,
            documentImporting = agentDocumentImporting,
            pendingToolCallId = agentPendingToolCallId,
            callSpec = agentCallSpec,
            callResult = agentCallResult,
            lookupContactPhone = agentLookupContactPhone,
            lookupContactInFlight = agentLookupContactInFlight,
            lookupDeviceContactsInFlight = agentLookupDeviceContactsInFlight,
            deviceContactSelection = agentDeviceContactSelection
        ),
        call = AssistantCallUiState(
            currentCallId = currentCallId,
            showAiCallPage = showAiCallPage,
            mode = callUiMode,
            handoffInFlight = handoffInFlight,
            callPage = callPageData
        ),
        task = AssistantTaskUiState(
            taskStatus = taskStatus,
            unresolvedTaskErrorStatus = unresolvedTaskErrorStatus,
            taskErrorRecoveryInProgress = taskErrorRecoveryInProgress,
            summary = summary,
            selectionSheet = selectionSheet,
            detailSupplement = detailSupplement
        ),
        location = AssistantLocationUiState(
            available = locationAvailable,
            displayText = locationDisplayText
        ),
        loading = loading,
        errorMessage = error
    )
}
