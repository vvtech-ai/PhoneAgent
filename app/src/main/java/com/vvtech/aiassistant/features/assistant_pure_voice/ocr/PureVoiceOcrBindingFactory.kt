package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import kotlinx.coroutines.CoroutineScope

@Composable
internal fun rememberPureVoiceOcrBinding(
    context: Context,
    scope: CoroutineScope,
    entryKey: Any?,
    enabled: Boolean,
    assistantState: Index9AssistantUiState?,
    hostCallbacks: PureVoiceOcrHostCallbacks?,
): PureVoiceOcrBinding {
    val timelineItems = assistantState?.timelineItems.orEmpty()
    val activeSessionId = assistantState?.taskId?.trim()?.takeIf(String::isNotBlank)
    val history = remember(enabled, timelineItems, activeSessionId) {
        if (enabled && activeSessionId != null) {
            PureVoiceOcrHistoryProjection.project(timelineItems, activeSessionId)
        } else {
            emptyList()
        }
    }
    val coordinator = rememberPureVoiceOcrCoordinator(
        context = context,
        scope = scope,
        entryKey = entryKey,
        history = history,
        hostCallbacks = hostCallbacks,
    )
    val state by coordinator.state.collectAsState()
    return PureVoiceOcrBinding(
        state = state,
        callbacks = PureVoiceOcrCallbacks { uri ->
            val clarificationSteps = assistantState?.clarificationSteps.orEmpty()
            coordinator.selectImage(
                imageUri = uri,
                anchorStepCount = pureVoiceOcrAnchorStepCount(clarificationSteps),
                taskId = assistantState?.taskId,
            )
        },
    )
}

internal fun pureVoiceOcrAnchorStepCount(steps: List<ClarificationStep>): Int =
    steps.indexOfLast(ClarificationStep::contributesToOcrSourceBoundary) + 1

private fun ClarificationStep.contributesToOcrSourceBoundary(): Boolean =
    role == VoiceRole.User ||
        text.isNotBlank() ||
        !thinking.isNullOrBlank() ||
        !toolCalls.isNullOrEmpty() ||
        toolCards.isNotEmpty() ||
        partialToolCalls.isNotEmpty() ||
        callConfirmSpec != null ||
        callResult != null ||
        batchCallResult != null ||
        callStatusEvents.isNotEmpty() ||
        streaming
