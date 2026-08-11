package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_conversation.ui.page.AssistantConversationLegacyHomePage
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeAgentCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeAgentSheetState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeComposerCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeComposerState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeNotificationCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeNotificationState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomePageCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeShellCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeTaskState
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore

@Composable
internal fun AssistantConversationPageHost(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    assistant: AssistantPageArgs
) {
    with(navigation) {
        with(assistant) {
            AssistantConversationLegacyHomePage(
                composerState = AssistantHomeComposerState(
                    assistantFocused = targetPage == FinalPage.Assistant,
                    composerOpen = homeComposerOpen,
                    composerMode = runCatching { ComposerMode.valueOf(composerMode) }
                        .getOrDefault(ComposerMode.Voice),
                    textDraft = taskTextDraft,
                    pureVoiceMode = pureVoiceMode,
                    apiAsrPartialText = assistantUiState.apiAsrPartialText,
                    apiTtsPlaying = assistantUiState.apiTtsPlaying
                ),
                taskState = AssistantHomeTaskState(
                    voiceRecording = assistantUiState.apiAsrListening,
                    taskStarted = effectiveTaskStarted,
                    taskUserText = effectiveTaskUserText,
                    aiThinking = effectiveAiThinking,
                    aiReplyVisible = effectiveAiReplyVisible,
                    taskStatus = assistantUiState.taskStatus,
                    clarificationSteps = assistantUiState.clarificationSteps,
                    processingTurn = assistantUiState.processingTurn
                ),
                agentSheetState = AssistantHomeAgentSheetState(
                    questions = assistantUiState.agentQuestions,
                    options = assistantUiState.agentOptions.takeUnless { pureVoiceMode },
                    documentRequest = assistantUiState.agentDocumentRequest,
                    documentImporting = assistantUiState.agentDocumentImporting
                ),
                notificationState = AssistantHomeNotificationState(
                    visible = homeNotificationVisible,
                    text = homeNotificationText,
                    extra = homeNotificationExtra,
                    statusKind = homeNotificationStatusKind
                ),
                callbacks = AssistantHomePageCallbacks(
                    shell = AssistantHomeShellCallbacks(
                        onQuickVoiceEntry = onQuickVoiceEntry,
                        onOpenTranslateDial = onOpenTranslateDial,
                        onBlockOffline = onBlockHomeCardIfOffline,
                        onComposerOpen = { onHomeComposerOpenChange(true) },
                        activeCallModelTitle = activeCallModelTitle,
                        onOpenCallModelSheet = onOpenCallModelSheet
                    ),
                    composer = AssistantHomeComposerCallbacks(
                        onModeChange = { mode -> onComposerModeChange(mode.name) },
                        onStartVoice = onStartVoice,
                        onStopVoice = onStopVoice,
                        onInterruptTts = onInterruptTts,
                        onTextDraftChange = onTaskTextDraftChange,
                        onSendText = onSendText,
                        onStopTask = {
                            AgentInitialSkillLaunchStore.clear()
                            onStopTask()
                        }
                    ),
                    agent = AssistantHomeAgentCallbacks(
                        onAnswerSubmit = { answers ->
                            assistantViewModel.onAgentAnswerSubmit(answers)
                        },
                        onOptionSelect = { optionId ->
                            assistantViewModel.onAgentOptionSelect(optionId)
                        },
                        onDocumentSelect = onAgentDocumentSelect,
                        onDocumentCancel = onAgentDocumentCancel,
                        onSheetDismiss = onAgentSheetDismiss,
                        onReplayTts = onReplayTts
                    ),
                    notification = AssistantHomeNotificationCallbacks(
                        onClick = onClickHomeNotification,
                        onDismiss = onDismissHomeNotification
                    )
                )
            )
        }
    }
}
