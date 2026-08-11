package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_call_evaluation.AgentCallEvaluationRoute
import com.vvtech.aiassistant.features.assistant_call_evaluation.AgentBatchCallEvaluationRoute
import com.vvtech.aiassistant.features.assistant_recording.callRecordingAnchor
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionsPayload

@Composable
internal fun FinalHomeThreadStep(
    step: ClarificationStep,
    onReplayTts: ((String) -> Unit)?
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
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
            step.batchCallResult?.let { result ->
                BatchCallResultCard(
                    result = result,
                    modifier = Modifier.padding(top = 4.dp, bottom = 4.dp)
                )
                if (!result.status.equals("RUNNING", ignoreCase = true)) {
                    AgentBatchCallEvaluationRoute(batchId = result.batchId)
                }
            }
            val showBatchCallStatus = step.callStatusEvents.isNotEmpty() &&
                (step.batchCallResult == null ||
                    step.batchCallResult.status.equals("RUNNING", ignoreCase = true))
            if (showBatchCallStatus) {
                BatchCallStatusCard(
                    events = step.callStatusEvents,
                    modifier = Modifier.padding(top = 4.dp, bottom = 4.dp)
                )
            }
            if (step.text.isNotBlank()) {
                FinalMessageBubble(text = step.text, user = false)
                if (!step.streaming && onReplayTts != null) {
                    Surface(
                        modifier = Modifier
                            .padding(start = 4.dp, top = 2.dp)
                            .size(28.dp)
                            .clickable { onReplayTts(step.text) },
                        shape = CircleShape,
                        color = Color(0xFFF0F4F8),
                        elevation = 0.dp
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = "重播",
                                fontSize = 10.sp,
                                color = Color(0xFF667085),
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
            if (step.streaming && step.text.isBlank() && step.thinking.isNullOrBlank() &&
                step.partialToolCalls.isEmpty() && step.toolCards.isEmpty() && step.callConfirmSpec == null) {
                FinalThinkingBubble()
            }
        }
        Spacer(modifier = Modifier.height(6.dp))
    }
}

@Composable
internal fun FinalHomeAgentSheets(
    agentQuestions: AskQuestionsPayload?,
    agentOptions: OptionsPayload?,
    agentDocumentRequest: DocumentImportRequestPayload?,
    agentDocumentImporting: Boolean,
    onAgentAnswerSubmit: ((Map<String, Any>) -> Unit)?,
    onAgentOptionSelect: ((String) -> Unit)?,
    onAgentDocumentSelect: (() -> Unit)?,
    onAgentDocumentCancel: (() -> Unit)?,
    onAgentSheetDismiss: (() -> Unit)?
) {
    if (agentQuestions != null) {
        FinalHomeBottomScrim(onDismiss = onAgentSheetDismiss) {
            AgentAskQuestionsSheet(
                payload = agentQuestions,
                onSubmit = { answers -> onAgentAnswerSubmit?.invoke(answers) }
            )
        }
    }

    if (agentOptions != null) {
        FinalHomeBottomScrim(onDismiss = onAgentSheetDismiss) {
            AgentOptionsSheet(
                options = agentOptions,
                onSelect = { optionId -> onAgentOptionSelect?.invoke(optionId) },
                onDismiss = { onAgentSheetDismiss?.invoke() }
            )
        }
    }

    if (agentDocumentRequest != null) {
        FinalHomeBottomScrim(onDismiss = onAgentDocumentCancel) {
            AgentDocumentImportSheet(
                request = agentDocumentRequest,
                importing = agentDocumentImporting,
                onSelect = { onAgentDocumentSelect?.invoke() },
                onCancel = { onAgentDocumentCancel?.invoke() }
            )
        }
    }
}

@Composable
private fun FinalHomeBottomScrim(
    onDismiss: (() -> Unit)?,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onDismiss?.invoke() },
        contentAlignment = Alignment.BottomCenter
    ) {
        Box(modifier = Modifier.clickable(enabled = false) { }) {
            content()
        }
    }
}
