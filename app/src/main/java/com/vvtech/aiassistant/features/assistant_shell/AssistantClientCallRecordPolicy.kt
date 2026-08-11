package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantClientCallResult
import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant_calls.callFailureUserMessage
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal fun buildAssistantClientCallRecord(
    result: AssistantClientCallResult
): FinalCallRecord {
    val formatter = SimpleDateFormat("HH:mm", Locale.getDefault())
    val start = formatter.format(Date(result.startedAtMillis))
    val end = formatter.format(Date(result.endedAtMillis))
    val duration = formatClientCallDuration(result.durationSeconds)
    val translation = result.request.mode == AssistantCallMode.TRANSLATION
    val status = when {
        result.success -> "已完成"
        result.failureReason.isNotBlank() -> "呼叫失败"
        else -> "已结束"
    }
    return FinalCallRecord(
        title = "${if (translation) "实时翻译" else "普通通话"} " +
            result.request.displayName.ifBlank { result.request.phoneNumber },
        status = status,
        meta = "$start · $duration",
        success = result.success,
        occurredAtMillis = result.startedAtMillis,
        phoneNumber = result.request.phoneNumber,
        startTimeText = start,
        endTimeText = end,
        durationText = duration,
        resultText = if (result.failureReason.isNotBlank()) {
            callFailureUserMessage(result.failureKind)
        } else {
            status
        },
        transcript = result.transcripts.map {
            TranscriptLine(
                role = if (it.role == "remote") TranscriptRole.Remote else TranscriptRole.Assistant,
                text = listOf(it.sourceText, it.translatedText)
                    .filter(String::isNotBlank)
                    .joinToString("\n")
            )
        }.filter { it.text.isNotBlank() },
        callId = result.sessionId,
        callKind = if (translation) DialCallKind.TRANSLATION else DialCallKind.NORMAL,
        dialCountryIso = result.request.countryIso,
        callerLanguageCode = result.request.myLanguage,
        calleeLanguageCode = result.request.peerLanguage
    )
}

internal fun formatClientCallDuration(seconds: Long): String =
    "%02d:%02d".format(seconds / 60, seconds % 60)

internal fun buildTranslationCallRecord(
    state: TranslationCallUiState,
    success: Boolean,
    endedAtMillis: Long = System.currentTimeMillis()
): FinalCallRecord {
    val formatter = SimpleDateFormat("HH:mm", Locale.getDefault())
    val start = formatter.format(Date(state.startedAtMs))
    val end = formatter.format(Date(endedAtMillis))
    val status = if (success) "已完成" else "呼叫失败"
    val number = state.plan?.targetE164.orEmpty()
    return FinalCallRecord(
        title = "实时翻译 ${state.targetDisplayName.ifBlank { number }}",
        status = status,
        meta = "$start · ${formatClientCallDuration(state.elapsedSeconds.toLong())}",
        success = success,
        occurredAtMillis = state.startedAtMs,
        phoneNumber = number,
        startTimeText = start,
        endTimeText = end,
        durationText = formatClientCallDuration(state.elapsedSeconds.toLong()),
        resultText = if (state.failureReason.isNotBlank()) {
            callFailureUserMessage(state.failureKind)
        } else {
            status
        },
        transcript = state.transcripts.map {
            TranscriptLine(
                role = if (it.sourceLeg == "merchant" || it.sourceLeg == "remote") {
                    TranscriptRole.Remote
                } else {
                    TranscriptRole.Assistant
                },
                text = listOf(it.sourceText, it.translatedText)
                    .filter(String::isNotBlank)
                    .joinToString("\n")
            )
        }.filter { it.text.isNotBlank() },
        callId = state.callId,
        callKind = DialCallKind.TRANSLATION,
        dialCountryIso = state.dialCountryIso,
        callerLanguageCode = state.myLanguage,
        calleeLanguageCode = state.peerLanguage
    )
}
