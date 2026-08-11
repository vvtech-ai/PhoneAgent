package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeAgentSheetState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeCardUi
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeConfigUiState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomePageCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomePageVisibility
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeComposerState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeNotificationState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeTaskState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeQuickTaskSection
import com.vvtech.aiassistant.features.assistant_home.resolveAssistantHomeProgressStage

private const val ShowHomeQuickTaskScenes = true

@Composable
internal fun FinalHomeAssistantPage(
    composerState: AssistantHomeComposerState,
    taskState: AssistantHomeTaskState,
    agentSheetState: AssistantHomeAgentSheetState = AssistantHomeAgentSheetState(),
    notificationState: AssistantHomeNotificationState = AssistantHomeNotificationState(),
    homeConfig: AssistantHomeConfigUiState = AssistantHomeConfigUiState(),
    onHomeCardEntry: (AssistantHomeCardUi) -> Unit = {},
    callbacks: AssistantHomePageCallbacks
) {
    val showComposer = taskState.taskStarted || composerState.assistantFocused || composerState.composerOpen
    val showQuickCards = ShowHomeQuickTaskScenes &&
        !taskState.taskStarted &&
        !showComposer &&
        taskState.clarificationSteps.isEmpty()

    FinalHomeAssistantPageV2(
        visibility = AssistantHomePageVisibility(
            showComposer = showComposer,
            showQuickCards = showQuickCards
        ),
        composerState = composerState,
        taskState = taskState,
        agentSheetState = agentSheetState,
        notificationState = notificationState,
        homeConfig = homeConfig,
        onHomeCardEntry = onHomeCardEntry,
        callbacks = callbacks
    )
}

@Composable
internal fun FinalHomeAssistantPageV2(
    visibility: AssistantHomePageVisibility,
    composerState: AssistantHomeComposerState,
    taskState: AssistantHomeTaskState,
    agentSheetState: AssistantHomeAgentSheetState,
    notificationState: AssistantHomeNotificationState,
    homeConfig: AssistantHomeConfigUiState,
    onHomeCardEntry: (AssistantHomeCardUi) -> Unit,
    callbacks: AssistantHomePageCallbacks
) {
    val listState = rememberLazyListState()
    val showEmptyState = taskState.clarificationSteps.isEmpty() &&
        !taskState.taskStarted &&
        !taskState.voiceRecording
    val showProgress = taskState.voiceRecording ||
        taskState.taskStarted ||
        taskState.clarificationSteps.isNotEmpty()
    val activeProgressStage = resolveAssistantHomeProgressStage(
        taskStatus = taskState.taskStatus,
        taskStarted = taskState.taskStarted,
        voiceRecording = taskState.voiceRecording,
        processingTurn = taskState.processingTurn,
        clarificationSteps = taskState.clarificationSteps
    )
    val threadEnterOffsetPx = with(LocalDensity.current) { 22.dp.toPx().toInt() }
    val threadExitOffsetPx = with(LocalDensity.current) { 14.dp.toPx().toInt() }
    val quickCardsOffsetPx = with(LocalDensity.current) { 10.dp.toPx().toInt() }
    val threadCount = (if (showProgress) 1 else 0) +
        taskState.clarificationSteps.size +
        (if (taskState.voiceRecording && taskState.clarificationSteps.isEmpty()) 1 else 0) +
        (if (taskState.taskStarted && taskState.clarificationSteps.isEmpty()) 1 else 0)

    LaunchedEffect(
        taskState.clarificationSteps.size,
        taskState.clarificationSteps.lastOrNull()?.text,
        taskState.voiceRecording,
        taskState.taskStarted,
        taskState.processingTurn,
        composerState.apiAsrPartialText
    ) {
        if (threadCount > 0) {
            listState.animateScrollToItem(threadCount - 1)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            FinalHomeTopBar()
            V88HomeNotificationBanner(
                visible = notificationState.visible,
                text = notificationState.text,
                extra = notificationState.extra,
                statusKind = notificationState.statusKind,
                onClick = callbacks.notification.onClick,
                onClose = callbacks.notification.onDismiss
            )
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 10.dp,
                    end = 10.dp,
                    bottom = if (visibility.showComposer) 224.dp else 120.dp
                )
            ) {
                if (showEmptyState) {
                    item {
                        FinalHomeEmptyStateCard(
                            callModelTitle = callbacks.shell.activeCallModelTitle,
                            onOpenCallModelSheet = callbacks.shell.onOpenCallModelSheet,
                            sloganTitle = homeConfig.slogan.line1,
                            sloganSubtitle = homeConfig.slogan.line2
                        )
                    }
                }

                item {
                    AnimatedVisibility(
                        visible = visibility.showQuickCards,
                        enter = fadeIn(
                            animationSpec = tween(
                                durationMillis = FinalThreadFadeDurationMs,
                                easing = FinalFadeEase
                            )
                        ) + slideInVertically(
                            animationSpec = tween(
                                durationMillis = FinalMotionDurationMs,
                                easing = FinalMotionEase
                            ),
                            initialOffsetY = { -quickCardsOffsetPx }
                        ),
                        exit = fadeOut(
                            animationSpec = tween(
                                durationMillis = FinalThreadFadeDurationMs,
                                easing = FinalFadeEase
                            )
                        ) + slideOutVertically(
                            animationSpec = tween(
                                durationMillis = FinalMotionDurationMs,
                                easing = FinalMotionEase
                            ),
                            targetOffsetY = { -quickCardsOffsetPx }
                        )
                    ) {
                        AssistantHomeQuickTaskSection(
                            cards = homeConfig.cards,
                            onEntry = onHomeCardEntry
                        )
                    }
                }

                if (showProgress) {
                    item {
                        FinalTaskProgressV2(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 6.dp, vertical = 6.dp),
                            activeStage = activeProgressStage
                        )
                    }
                }

                if (taskState.clarificationSteps.isNotEmpty()) {
                    items(taskState.clarificationSteps.size) { index ->
                        FinalHomeThreadStep(
                            step = taskState.clarificationSteps[index],
                            onReplayTts = callbacks.agent.onReplayTts
                        )
                    }
                } else if (taskState.voiceRecording) {
                    item {
                        AnimatedVisibility(
                            visible = true,
                            enter = fadeIn(
                                animationSpec = tween(
                                    durationMillis = FinalThreadFadeDurationMs,
                                    easing = FinalFadeEase
                                )
                            ) + slideInVertically(
                                animationSpec = tween(
                                    durationMillis = FinalMotionDurationMs,
                                    easing = FinalMotionEase
                                ),
                                initialOffsetY = { threadEnterOffsetPx }
                            ),
                            exit = fadeOut(
                                animationSpec = tween(
                                    durationMillis = FinalThreadFadeDurationMs,
                                    easing = FinalFadeEase
                                )
                            ) + slideOutVertically(
                                animationSpec = tween(
                                    durationMillis = FinalMotionDurationMs,
                                    easing = FinalMotionEase
                                ),
                                targetOffsetY = { threadExitOffsetPx }
                            )
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 6.dp)
                            ) {
                                FinalVoiceRecognitionBubbleV3()
                            }
                        }
                    }
                } else if (taskState.taskStarted) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 6.dp)
                        ) {
                            FinalMessageBubble(text = taskState.taskUserText, user = true)
                            if (taskState.aiThinking || taskState.processingTurn) {
                                FinalThinkingBubble()
                            }
                            if (
                                taskState.aiReplyVisible &&
                                !taskState.aiThinking &&
                                !taskState.processingTurn
                            ) {
                                FinalMessageBubble(text = "我会继续按当前任务信息推进。", user = false)
                            }
                        }
                    }
                }
            }
        }

        val composerVisibleState = remember { MutableTransitionState(false) }
        LaunchedEffect(visibility.showComposer) {
            composerVisibleState.targetState = visibility.showComposer
        }
        AnimatedVisibility(
            visibleState = composerVisibleState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .imePadding()
                .padding(start = 14.dp, end = 14.dp, bottom = 16.dp),
            enter = fadeIn(
                animationSpec = tween(
                    durationMillis = 340,
                    easing = FinalFadeEase
                )
            ) + slideInVertically(
                animationSpec = tween(
                    durationMillis = 440,
                    easing = FinalMotionEase
                ),
                initialOffsetY = { (it * 14) / 10 }
            ),
            exit = fadeOut(
                animationSpec = tween(
                    durationMillis = 300,
                    easing = FinalFadeEase
                )
            ) + slideOutVertically(
                animationSpec = tween(
                    durationMillis = 420,
                    easing = FinalMotionEase
                ),
                targetOffsetY = { (it * 12) / 10 }
            )
        ) {
            FinalComposerPanelV2(
                mode = composerState.composerMode,
                voiceRecording = taskState.voiceRecording,
                taskStarted = taskState.taskStarted,
                textDraft = composerState.textDraft,
                apiAsrPartialText = composerState.apiAsrPartialText,
                apiTtsPlaying = composerState.apiTtsPlaying,
                processingTurn = taskState.processingTurn,
                onOpen = callbacks.shell.onComposerOpen,
                onModeChange = callbacks.composer.onModeChange,
                onStartVoice = callbacks.composer.onStartVoice,
                onStopVoice = callbacks.composer.onStopVoice,
                onInterruptTts = callbacks.composer.onInterruptTts,
                onTextDraftChange = callbacks.composer.onTextDraftChange,
                onSendText = callbacks.composer.onSendText,
                onStopTask = callbacks.composer.onStopTask
            )
        }

        FinalHomeAgentSheets(
            agentQuestions = agentSheetState.questions,
            agentOptions = agentSheetState.options,
            agentDocumentRequest = agentSheetState.documentRequest,
            agentDocumentImporting = agentSheetState.documentImporting,
            onAgentAnswerSubmit = callbacks.agent.onAnswerSubmit,
            onAgentOptionSelect = callbacks.agent.onOptionSelect,
            onAgentDocumentSelect = callbacks.agent.onDocumentSelect,
            onAgentDocumentCancel = callbacks.agent.onDocumentCancel,
            onAgentSheetDismiss = callbacks.agent.onSheetDismiss
        )
    }
}
