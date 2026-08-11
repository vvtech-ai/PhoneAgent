package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant_call_evaluation.AgentCallEvaluationRoute
import com.vvtech.aiassistant.features.assistant_recording.callRecordingAnchor
import androidx.compose.ui.unit.sp

@Composable
internal fun SingleFlowHeader(
    stage: Int,
    closeTaskAction: (() -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Phone Agent",
                fontSize = 30.sp,
                lineHeight = 30.sp,
                letterSpacing = 0.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color(0xFF10131A)
            )
            Text(
                text = "电话智能体 - 你的语音分身",
                fontSize = 13.sp,
                color = Color(0xFF717888),
                modifier = Modifier.padding(top = 6.dp)
            )
        }
        Surface(
            modifier = Modifier
                .size(40.dp)
                .clickable(enabled = closeTaskAction != null) {
                    closeTaskAction?.invoke()
                },
            shape = RoundedCornerShape(999.dp),
            color = Color.White.copy(alpha = 0.76f),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f))
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Rounded.Close,
                    contentDescription = "close task",
                    tint = Color(0xFF1B1D21),
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }

    SingleFlowStageProgress(stage = stage)
}

@Composable
private fun SingleFlowStageProgress(stage: Int) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 2.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SfStageLabels.forEachIndexed { index, label ->
                val stageNumber = index + 1
                val stageTextColor = when {
                    stage > stageNumber -> Color(0xFF34C759)
                    stage == stageNumber -> Color(0xFF007AFF)
                    else -> Color(0xFF8F98A8)
                }
                Text(
                    text = label,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = stageTextColor
                )
            }
        }
        Row(
            modifier = Modifier.padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SfStageLabels.indices.forEach { index ->
                val stageNumber = index + 1
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color(0xFFDDE4EF))
                ) {
                    if (stage >= stageNumber) {
                        val fillColors = if (stage > stageNumber) {
                            listOf(Color(0xFF30D158), Color(0xFF34C759))
                        } else {
                            listOf(Color(0xFF0A84FF), Color(0xFF49A4FF))
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Brush.horizontalGradient(fillColors))
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun ColumnScope.SingleFlowDialogueList(
    listState: LazyListState,
    realFlowEnabled: Boolean,
    assistantState: Index9AssistantUiState?,
    inputMode: SfInputMode,
    voiceLanguage: VoiceLanguage,
    composerReserve: Dp,
    threadItems: List<SfThreadItem>,
    savedContacts: List<PersonalInfoEntry>,
    supplementContact: EffectiveTaskContact?,
    preferredSavedContact: PersonalInfoEntry?,
    manualContactMode: Boolean,
    contactInputError: String?,
    voiceContactPromptTaskId: String?,
    selectedDetailQuestionIds: List<String>,
    onRealSelectionOptionSelected: (SelectionSheetOption) -> Unit,
    onConfirmSavedContact: (PersonalInfoEntry) -> Unit,
    onManualContact: () -> Unit,
    onToggleQuestion: (DetailSupplementQuestionData) -> Unit,
    onConfirmDetails: (DetailSupplementPageData, List<String>) -> Unit,
    onSkipDetails: () -> Unit,
    onConfirmSummary: () -> Unit,
    onMockCtaClick: () -> Unit
) {
    LazyColumn(
        state = listState,
        modifier = Modifier
            .fillMaxWidth()
            .weight(1f)
            .padding(top = 10.dp),
        contentPadding = PaddingValues(bottom = composerReserve),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        val state = assistantState
        if (realFlowEnabled && state != null) {
            if (state.clarificationSteps.isEmpty() && !state.processingTurn && !state.loading) {
                item { FinalHomeEmptyStateCard() }
            }
            items(state.clarificationSteps.size) { index ->
                val step = state.clarificationSteps[index]
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 6.dp)
                ) {
                    if (step.role == VoiceRole.User) {
                        FinalMessageBubble(text = step.text, user = true)
                    } else {
                        AgentThinkingBlock(
                            thinking = step.thinking,
                            toolCalls = step.toolCalls,
                            toolCards = step.toolCards,
                            streaming = step.streaming,
                            thinkingStartedAt = step.thinkingStartedAt,
                            thinkingDurationMs = step.thinkingDurationMs,
                            partialToolCalls = step.partialToolCalls
                        )
                        step.callConfirmSpec?.let { spec ->
                            AgentCallConfirmCard(
                                callSpec = spec,
                                modifier = Modifier.padding(top = 4.dp, bottom = 4.dp)
                            )
                        }
                        step.callResult?.let { result ->
                            AgentCallResultCard(result = result)
                            AgentCallEvaluationRoute(callId = callRecordingAnchor(result))
                        }
                        if (step.text.isNotBlank()) {
                            FinalMessageBubble(text = step.text, user = false)
                        }
                        if (step.streaming && step.text.isBlank() && step.thinking.isNullOrBlank() &&
                            step.partialToolCalls.isEmpty() && step.toolCards.isEmpty() && step.callConfirmSpec == null
                        ) {
                            FinalThinkingBubble()
                        }
                    }
                }
            }
            if (state.processingTurn || state.loading) {
                item(key = "real_processing") {
                    SingleFlowBubbleRow {
                        FinalThinkingBubble()
                    }
                }
            }
            state.error?.takeIf { it.isNotBlank() }?.let { error ->
                item(key = "real_error") {
                    SingleFlowBubbleRow {
                        FinalMessageBubble(text = sanitizeUserFacingError(error, voiceLanguage), user = false)
                    }
                }
            }
            state.liveUserTranscript?.trim()?.takeIf { it.isNotBlank() }?.let { liveText ->
                item(key = "real_live_user") {
                    SingleFlowBubbleRow {
                        FinalMessageBubble(text = liveText, user = true)
                    }
                }
            } ?: run {
                if (state.voiceConnecting || state.listening) {
                    item(key = "real_voice_wave") {
                        SingleFlowBubbleRow {
                            FinalVoiceRecognitionBubbleV3()
                        }
                    }
                }
            }
            state.liveAssistantTranscript?.trim()?.takeIf { it.isNotBlank() }?.let { liveText ->
                item(key = "real_live_assistant") {
                    SingleFlowBubbleRow {
                        FinalMessageBubble(text = liveText, user = false)
                    }
                }
            }
            state.selectionSheet?.let { sheet ->
                item(key = "real_selection") {
                    SfSelectionSheetCard(
                        sheet = sheet,
                        onSelect = onRealSelectionOptionSelected
                    )
                }
            }
            if (
                inputMode == SfInputMode.Voice &&
                realFlowEnabled &&
                state.detailSupplement != null &&
                supplementContact == null &&
                preferredSavedContact != null &&
                !manualContactMode &&
                voiceContactPromptTaskId == state.detailSupplement.taskId
            ) {
                item(key = "real_voice_contact_confirm") {
                    SfVoiceContactConfirmCard(contact = preferredSavedContact)
                }
            }
            state.detailSupplement?.takeIf { inputMode != SfInputMode.Voice }?.let { supplement ->
                val visibleSupplement = if (inputMode == SfInputMode.Voice) {
                    sfVoiceDetailSupplement(supplement)
                } else {
                    supplement
                }
                item(key = "real_detail_supplement") {
                    SfDetailSupplementCard(
                        supplement = visibleSupplement,
                        savedContacts = savedContacts,
                        selectedContact = supplementContact,
                        manualContactMode = manualContactMode,
                        contactInputError = contactInputError,
                        selectedQuestionIds = selectedDetailQuestionIds,
                        onConfirmSavedContact = onConfirmSavedContact,
                        onManualContact = onManualContact,
                        onToggleQuestion = onToggleQuestion,
                        onConfirmDetails = {
                            onConfirmDetails(visibleSupplement, selectedDetailQuestionIds)
                        },
                        onSkipDetails = onSkipDetails
                    )
                }
            }
            state.summary?.let { summary ->
                item(key = "real_summary") {
                    SfRealSummaryCard(
                        summary = summary,
                        confirmLabel = state.confirmLabel,
                        showAction = inputMode != SfInputMode.Voice,
                        onConfirm = onConfirmSummary
                    )
                }
            }
            if (state.showAiCallPage || sfHasVisibleCallDialogue(state.callPageData)) {
                item(key = "real_call_status") {
                    SfRealCallStatusCard(
                        data = state.callPageData,
                        mode = state.callUiMode,
                        handoffInFlight = state.handoffInFlight
                    )
                }
            }
        } else {
            items(threadItems, key = { it.id }) { item ->
                when (item) {
                    is SfThreadItem.UserText -> SfUserBubble(text = item.text)
                    is SfThreadItem.UserWave -> SfUserWaveBubble()
                    is SfThreadItem.AiText -> SfAiBubble(text = item.text)
                    is SfThreadItem.AiThinking -> SfThinkingBubble(steps = item.steps)
                    is SfThreadItem.Summary -> SfSummaryCard(text = item.text)
                    is SfThreadItem.Options -> SfRestaurantOptionsCard(options = item.options)
                    is SfThreadItem.AiCta -> SfAiCtaBubble(
                        text = item.text,
                        onClick = onMockCtaClick
                    )
                }
            }
        }
    }
}

@Composable
private fun SingleFlowBubbleRow(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp)
    ) {
        content()
    }
}
