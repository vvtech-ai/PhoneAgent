package com.vvtech.aiassistant.features.assistant_pure_voice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.BatchCallResultCard
import com.vvtech.aiassistant.features.assistant.BatchCallStatusCard
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PureVoiceBubble
import com.vvtech.aiassistant.features.assistant.PureVoiceCallCard
import com.vvtech.aiassistant.features.assistant.PureVoiceCallConfirmSummaryCard
import com.vvtech.aiassistant.features.assistant.PureVoiceCallResultCard
import com.vvtech.aiassistant.features.assistant.PureVoiceCallResultPendingTip
import com.vvtech.aiassistant.features.assistant.PureVoiceThinkingCard
import com.vvtech.aiassistant.features.assistant.PureVoiceThreadStageIndicator
import com.vvtech.aiassistant.features.assistant.PureVoiceToolCard
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.pureVoiceToolIcon
import com.vvtech.aiassistant.features.assistant.pureVoiceHasVisibleCallDialogue
import com.vvtech.aiassistant.features.assistant_agent.AgentStreamCallTranscriptPolicy
import com.vvtech.aiassistant.features.assistant_call_evaluation.AgentCallEvaluationRoute
import com.vvtech.aiassistant.features.assistant_call_evaluation.AgentBatchCallEvaluationRoute
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrDisplayOrdering
import com.vvtech.aiassistant.features.assistant_recording.PureVoiceCallRecordingRoute
import com.vvtech.aiassistant.features.assistant_recording.callRecordingAnchor
import com.vvtech.aiassistant.features.assistant_tasks.callResultStatusText

@Composable
internal fun PureVoiceThreadList(
    listState: LazyListState,
    renderState: PureVoiceThreadRenderState,
    voiceLanguage: VoiceLanguage,
    threadHorizontalPadding: Dp,
    processingTurn: Boolean,
    sceneType: String?,
    summary: SummaryData?,
    onRecordingCardRevealed: () -> Unit,
) {
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = threadHorizontalPadding,
            end = threadHorizontalPadding,
            top = 18.dp,
            bottom = 0.dp
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        val entryPrecheck = renderState.precheck?.takeUnless { it.inline }
        val inlinePrecheck = renderState.precheck?.takeIf { it.inline }
        entryPrecheck?.let { state ->
            item(key = if (state.inline) "precheck_inline" else "precheck_entry") {
                PureVoicePrecheckCard(state = state)
            }
        }
        if (renderState.showEmptyState) {
            item(key = "empty") {
                PureVoiceThreadStageIndicator(
                    text = currentAppText(
                        "请按住下方语音按钮，说出你的需求。",
                        "Press and hold the voice button below, then say what you need."
                    ),
                    done = false
                )
            }
        }
        val ocrByAnchor = PureVoiceOcrDisplayOrdering.byAnchor(
            renderState.ocrAttachments,
            renderState.displayClarificationSteps.size,
        )
        val clarificationKeys = PureVoiceClarificationItemKeyPolicy.keys(
            renderState.displayClarificationSteps
        )
        ocrByAnchor[0].orEmpty().forEach { pureVoiceOcrAttachmentItems(it) }
        renderState.displayClarificationSteps.forEachIndexed { index, step ->
            item(key = clarificationKeys[index]) {
                PureVoiceClarificationStepItem(
                    index = index,
                    step = step,
                    processingTurn = processingTurn,
                    sceneType = sceneType,
                    summary = summary,
                    onRecordingCardRevealed = onRecordingCardRevealed,
                )
            }
            ocrByAnchor[index + 1].orEmpty().forEach { pureVoiceOcrAttachmentItems(it) }
        }
        renderState.visibleLiveUser?.let { text ->
            item(key = "live_user") {
                PureVoiceBubble(text = text, user = true, streaming = true, keyHint = -1)
            }
        }
        renderState.visibleLiveAssistant?.let { text ->
            item(key = "live_assistant") {
                PureVoiceBubble(text = text, user = false, streaming = true, keyHint = -2)
            }
        }
        renderState.displayError?.let { text ->
            item(key = "network_error") {
                PureVoiceBubble(text = text, user = false, streaming = false, keyHint = -3, error = true)
            }
        }
        if (renderState.showProcessingPlaceholder) {
            item(key = "processing") {
                PureVoiceThinkingCard(
                    title = "Phone Agent",
                    steps = listOf(renderState.displayStatus.ifBlank {
                        currentAppText("AI 思考中...", "AI is thinking...")
                    })
                )
            }
        }
        renderState.visibleCallPage?.let { data ->
            item(key = "call") {
                PureVoiceCallCard(data = data)
            }
        }
        renderState.visibleCallTranscript?.let { data ->
            item(key = "call_transcript") {
                PureVoiceCallCard(data = data)
            }
        }
        renderState.visiblePendingCallResultText?.let { text ->
            item(key = "call_result_pending") {
                PureVoiceCallResultPendingTip(text = text)
            }
        }
        renderState.visibleCallResult?.let { data ->
            item(key = "call_result") {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (pureVoiceHasVisibleCallDialogue(data)) {
                        PureVoiceCallRecordingRoute(
                            callId = callRecordingAnchor(data.callResult),
                            onCardRevealed = onRecordingCardRevealed,
                        )
                    }
                    PureVoiceCallResultCard(sceneType = sceneType, summary = summary, data = data)
                    AgentCallEvaluationRoute(callId = callRecordingAnchor(data.callResult))
                }
            }
        }
        inlinePrecheck?.let { state ->
            item(key = "precheck_inline") {
                PureVoicePrecheckCard(state = state)
            }
        }
        // A separate tail anchor keeps the end visible even when the last content item is taller than the viewport.
        item(key = "thread_end") {
            Spacer(modifier = Modifier.height(1.dp))
        }
    }
}

@Composable
private fun PureVoiceClarificationStepItem(
    index: Int,
    step: ClarificationStep,
    processingTurn: Boolean,
    sceneType: String?,
    summary: SummaryData?,
    onRecordingCardRevealed: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (step.role == VoiceRole.User) {
            PureVoiceBubble(
                text = step.text,
                user = true,
                streaming = step.streaming,
                keyHint = index
            )
        } else {
            PureVoiceAssistantStepItem(
                index = index,
                step = step,
                processingTurn = processingTurn,
                sceneType = sceneType,
                summary = summary,
                onRecordingCardRevealed = onRecordingCardRevealed,
            )
        }
    }
}

@Composable
private fun PureVoiceAssistantStepItem(
    index: Int,
    step: ClarificationStep,
    processingTurn: Boolean,
    sceneType: String?,
    summary: SummaryData?,
    onRecordingCardRevealed: () -> Unit,
) {
    val thinkingText = step.thinking.orEmpty()
    val showThinking = thinkingText.isNotBlank() &&
        (processingTurn || !step.streaming || step.thinkingDurationMs != null)
    if (showThinking) {
        PureVoiceThinkingCard(
            title = "Phone Agent",
            steps = thinkingText.lines().map { it.trim() }.filter { it.isNotBlank() },
            processing = processingTurn && step.streaming && step.thinkingDurationMs == null
        )
    }
    if (step.partialToolCalls.isNotEmpty()) {
        step.partialToolCalls.forEach { tool ->
            PureVoiceToolCard(
                icon = tool.name.firstOrNull()?.uppercaseChar()?.toString() ?: "T",
                name = tool.name,
                body = tool.argsPreview,
                result = tool.result
            )
        }
    }
    if (!step.toolCalls.isNullOrEmpty()) {
        step.toolCalls.forEach { tool ->
            PureVoiceToolCard(
                icon = tool.name.firstOrNull()?.uppercaseChar()?.toString() ?: "T",
                name = tool.name,
                body = tool.args,
                result = tool.result
            )
        }
    }
    if (step.toolCards.isNotEmpty()) {
        step.toolCards.forEach { tool ->
            PureVoiceToolCard(
                icon = pureVoiceToolIcon(tool.toolName, tool.methodLabel),
                name = tool.methodLabel,
                body = tool.body,
                result = tool.result
            )
        }
    }
    step.callConfirmSpec?.let { spec ->
        PureVoiceCallConfirmSummaryCard(callSpec = spec)
    }
    step.callResult?.let { result ->
        val data = callResultThreadPageData(result = result, sceneType = sceneType)
        if (pureVoiceHasVisibleCallDialogue(data)) {
            PureVoiceCallCard(data = data)
            PureVoiceCallRecordingRoute(
                callId = callRecordingAnchor(result),
                onCardRevealed = onRecordingCardRevealed,
            )
        }
        PureVoiceCallResultCard(sceneType = sceneType, summary = summary, data = data)
        AgentCallEvaluationRoute(callId = callRecordingAnchor(result))
    }
    step.batchCallResult?.let { result ->
        BatchCallResultCard(result = result)
        if (!result.status.equals("RUNNING", ignoreCase = true)) {
            AgentBatchCallEvaluationRoute(batchId = result.batchId)
        }
    }
    val showBatchCallStatus = step.callStatusEvents.isNotEmpty() &&
        (step.batchCallResult == null ||
            step.batchCallResult.status.equals("RUNNING", ignoreCase = true))
    if (showBatchCallStatus) {
        BatchCallStatusCard(events = step.callStatusEvents)
    }
    if (step.text.isNotBlank()) {
        PureVoiceBubble(
            text = step.text,
            user = false,
            streaming = step.streaming,
            keyHint = index
        )
    }
}

internal fun callResultThreadPageData(
    result: CallResultPayload,
    sceneType: String?
): CallPageData {
    val current = CallPageData(
        name = result.metadata?.get("targetName").orEmpty().ifBlank { currentAppText("AI 外呼", "AI Call") },
        sub = result.metadata?.get("phoneNumber").orEmpty(),
        status = "",
        transcript = emptyList(),
        callResult = result,
    )
    return AgentStreamCallTranscriptPolicy.callResultPageData(
        current = current,
        response = AgentChatResponse(
            sessionId = "",
            type = "CALL_RESULT",
            text = null,
            callResult = result
        ),
        resultStatusText = callResultStatusText(result, sceneType)
    )
}
