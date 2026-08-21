package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrAttachment
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrDisplayOrdering
import com.vvtech.aiassistant.features.assistant.pureVoiceHasVisibleCallDialogue
import com.vvtech.aiassistant.features.assistant.pureVoiceLiveLabel
import com.vvtech.aiassistant.features.assistant.pureVoiceLooksLikeCallResultStatus
import com.vvtech.aiassistant.features.assistant.pureVoiceLooksLikeCallResultSummaryLine
import com.vvtech.aiassistant.features.assistant.pureVoiceLooksLikePendingCallResultStatus
import com.vvtech.aiassistant.features.assistant.pureVoiceSanitizeCallPageData
import com.vvtech.aiassistant.features.assistant.pureVoiceSanitizeStepForDisplay
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingError
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class PureVoiceThreadRenderState(
    val displayStatus: String,
    val displayError: String?,
    val precheck: PureVoicePrecheckUiState?,
    val displayClarificationSteps: List<ClarificationStep>,
    val ocrAttachments: List<PureVoiceOcrAttachment>,
    val visibleLiveUser: String?,
    val visibleLiveAssistant: String?,
    val visibleCallPage: CallPageData?,
    val visibleCallTranscript: CallPageData?,
    val visiblePendingCallResultText: String?,
    val visibleCallResult: CallPageData?,
    val showCallResult: Boolean,
    val showEmptyState: Boolean,
    val showProcessingPlaceholder: Boolean,
    val threadCount: Int,
    val scrollSignature: String,
    val liveText: String
)

internal fun buildPureVoiceThreadRenderState(
    voiceLanguage: VoiceLanguage,
    state: PureVoiceState,
    processingTurn: Boolean,
    liveUserTranscript: String?,
    liveAssistantTranscript: String?,
    status: String,
    clarificationSteps: List<ClarificationStep>,
    error: String?,
    precheck: PureVoicePrecheckUiState?,
    callPageData: CallPageData?,
    showCallPage: Boolean,
    ocrAttachments: List<PureVoiceOcrAttachment> = emptyList(),
): PureVoiceThreadRenderState {
    val displayStatus = sanitizeUserFacingNetworkText(status, voiceLanguage)
    val displayError = error
        ?.trim()
        ?.takeIf { it.isNotBlank() }
        ?.let { sanitizeUserFacingError(it, voiceLanguage) }
    val conversationProjection =
        PureVoiceConversationStepProjector.projectWithBoundaries(clarificationSteps)
    val baseDisplayClarificationSteps = conversationProjection.steps
        .map { pureVoiceSanitizeStepForDisplay(it, voiceLanguage) }
    // Receipt order and visibility belong to the timeline adapter. This renderer only
    // sanitizes the supplied projection and must not move a receipt to the tail.
    val displayClarificationSteps = baseDisplayClarificationSteps
    val displayOcrAttachments = PureVoiceOcrDisplayOrdering.ordered(
        ocrAttachments.map { attachment ->
            attachment.copy(
                anchorStepCount = conversationProjection.displayBoundaryFor(
                    attachment.anchorStepCount
                )
            )
        }
    )
    val visibleLiveUser = liveUserTranscript
        ?.trim()
        ?.takeIf { text ->
            text.isNotBlank() &&
                displayClarificationSteps.lastOrNull { step -> step.role == VoiceRole.User }?.text != text
        }
    val visibleLiveAssistant = liveAssistantTranscript
        ?.trim()
        ?.let { sanitizeUserFacingNetworkText(it, voiceLanguage) }
        ?.takeIf { text ->
            text.isNotBlank() &&
                displayClarificationSteps.lastOrNull { step -> step.role == VoiceRole.Assistant }?.text != text
        }
    val visibleWelcomePrompt = visibleLiveAssistant?.takeIf {
        it == voiceLanguage.firstWelcome ||
            it == voiceLanguage.repeatWelcome ||
            it == voiceLanguage.standbyText
    }
    val hasTimelineCallReceipt = baseDisplayClarificationSteps.any {
        it.callResult != null || it.batchCallResult != null
    }
    val displayCallPageData = callPageData
        ?.let { pureVoiceSanitizeCallPageData(it, voiceLanguage) }
        ?.takeUnless {
            !showCallPage &&
                hasTimelineCallReceipt
        }
    val visibleCallPage = displayCallPageData?.takeIf { showCallPage && pureVoiceHasVisibleCallDialogue(it) }
    val visibleCallTranscript = displayCallPageData?.takeIf {
        !showCallPage && pureVoiceHasVisibleCallDialogue(it)
    }
    val visiblePendingCallResultText = displayCallPageData
        ?.status
        ?.trim()
        ?.takeIf { !showCallPage && pureVoiceLooksLikePendingCallResultStatus(it) }
    val visibleCallResult = displayCallPageData?.takeIf {
        !showCallPage && !pureVoiceLooksLikePendingCallResultStatus(it.status) && (
            pureVoiceLooksLikeCallResultStatus(it.status) ||
                it.transcript.any { line ->
                    line.role == TranscriptRole.Note && pureVoiceLooksLikeCallResultSummaryLine(line.text)
                }
            )
    }
    val showCallResult = visibleCallResult != null
    val hasRestoredThreadContent = displayClarificationSteps.isNotEmpty() ||
        displayOcrAttachments.isNotEmpty() ||
        visibleLiveUser != null ||
        visibleLiveAssistant != null ||
        visibleCallTranscript != null ||
        visiblePendingCallResultText != null ||
        visibleCallResult != null
    val visiblePrecheck = precheck
        ?.takeIf { it.visible && !showCallPage }
        ?.copy(inline = hasRestoredThreadContent)
    val threadDisplayError = displayError
        ?.takeUnless { visiblePrecheck != null && !visiblePrecheck.inline }
    val showEmptyState = displayClarificationSteps.isEmpty() &&
        displayOcrAttachments.isEmpty() &&
        visibleLiveUser == null &&
        visibleLiveAssistant == null &&
        visibleCallPage == null &&
        visibleCallTranscript == null &&
        visiblePendingCallResultText == null &&
        visiblePrecheck == null &&
        threadDisplayError == null
    val showProcessingPlaceholder = processingTurn &&
        visiblePendingCallResultText == null &&
        !displayClarificationSteps.hasActiveStreamingThinking()
    val threadCount = displayClarificationSteps.size +
        listOfNotNull(
            visiblePrecheck,
            visibleLiveUser,
            visibleLiveAssistant,
            threadDisplayError,
            visibleCallPage,
            visibleCallTranscript,
            visiblePendingCallResultText,
            visibleCallResult
        ).size +
        displayOcrAttachments.size * 2 +
        (if (showEmptyState) 1 else 0) +
        (if (showProcessingPlaceholder) 1 else 0)
    val scrollSignature = buildPureVoiceThreadScrollSignature(
        threadCount = threadCount,
        visibleLiveUser = visibleLiveUser,
        visibleLiveAssistant = visibleLiveAssistant,
        processingTurn = processingTurn,
        displayStatus = displayStatus,
        displayError = threadDisplayError,
        precheck = visiblePrecheck,
        displayClarificationSteps = displayClarificationSteps,
        ocrAttachments = displayOcrAttachments,
        displayCallPageData = displayCallPageData,
        visiblePendingCallResultText = visiblePendingCallResultText
    )
    val liveText = if (visiblePrecheck != null) {
        currentAppText("任务执行环境检测中...", "Checking task environment...")
    } else if (showCallResult) {
        currentAppText("任务已完成", "Task completed")
    } else if (visibleWelcomePrompt != null && displayClarificationSteps.isEmpty()) {
        pureVoiceLiveLabel(PureVoiceState.Standby, voiceLanguage, visibleWelcomePrompt, showCallPage)
    } else {
        pureVoiceLiveLabel(state, voiceLanguage, displayStatus, showCallPage)
    }
    return PureVoiceThreadRenderState(
        displayStatus = displayStatus,
        displayError = threadDisplayError,
        precheck = visiblePrecheck,
        displayClarificationSteps = displayClarificationSteps,
        ocrAttachments = displayOcrAttachments,
        visibleLiveUser = visibleLiveUser,
        visibleLiveAssistant = visibleLiveAssistant,
        visibleCallPage = visibleCallPage,
        visibleCallTranscript = visibleCallTranscript,
        visiblePendingCallResultText = visiblePendingCallResultText,
        visibleCallResult = visibleCallResult,
        showCallResult = showCallResult,
        showEmptyState = showEmptyState,
        showProcessingPlaceholder = showProcessingPlaceholder,
        threadCount = threadCount,
        scrollSignature = scrollSignature,
        liveText = liveText
    )
}

private fun List<ClarificationStep>.hasActiveStreamingThinking(): Boolean =
    any { step ->
        step.role == VoiceRole.Assistant &&
            !step.thinking.isNullOrBlank() &&
            step.streaming &&
            step.thinkingDurationMs == null
    }

private fun buildPureVoiceThreadScrollSignature(
    threadCount: Int,
    visibleLiveUser: String?,
    visibleLiveAssistant: String?,
    processingTurn: Boolean,
    displayStatus: String,
    displayError: String?,
    precheck: PureVoicePrecheckUiState?,
    displayClarificationSteps: List<ClarificationStep>,
    ocrAttachments: List<PureVoiceOcrAttachment>,
    displayCallPageData: CallPageData?,
    visiblePendingCallResultText: String?
): String = buildString {
    append(threadCount)
    append('|').append(visibleLiveUser.orEmpty())
    append('|').append(visibleLiveAssistant.orEmpty())
    append('|').append(processingTurn).append(displayStatus)
    append('|').append(displayError.orEmpty())
    precheck?.items?.forEach { item ->
        append('|').append(item.title).append(':').append(item.value).append(':').append(item.state)
    }
    displayClarificationSteps.forEach { step ->
        append('|').append(step.role).append(':').append(step.text).append(':').append(step.streaming)
        append(':').append(step.thinking.orEmpty())
        append(':').append(step.partialToolCalls.size).append(':').append(step.toolCalls?.size ?: 0)
        append(':').append(step.toolCards.size)
    }
    ocrAttachments.forEach { attachment ->
        append('|').append(attachment.attachmentId).append(':').append(attachment.status)
        append(':').append(attachment.fields.size).append(':').append(attachment.fullText)
    }
    append('|').append(displayCallPageData?.status.orEmpty())
    append('|').append(visiblePendingCallResultText.orEmpty())
    displayCallPageData?.transcript?.forEach { line ->
        append('|').append(line.role).append(':').append(line.text)
    }
}
