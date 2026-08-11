package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.UUID

internal class AssistantDoubaoTranscriptAccumulator(
    private val speaker: String,
    private val sourceLanguage: String,
    private val targetLanguage: String,
    private val log: (String) -> Unit = { AppFileLogger.i(LogTag, it) },
    private val clockMillis: () -> Long = { System.nanoTime() / 1_000_000L }
) {
    private var currentTurnId = ""
    private var sourceText = ""
    private var translatedText = ""
    private var turnClosed = true
    private var commaCompletedAtMillis: Long? = null
    private var continuationGapMillis: Long? = null
    private var sourceNeedsContinuationJoin = false
    private var translationNeedsContinuationJoin = false

    fun applySource(text: String, protoEvent: Int): AssistantTranslationTranscript? {
        val clean = text.trim()
        if (clean.isBlank()) return null
        val newTurn = ensureOpenTurn(
            forceNew = protoEvent == AssistantDoubaoProto.SourceStart,
            allowCommaContinuation = true
        )
        sourceText = when {
            sourceNeedsContinuationJoin -> {
                sourceNeedsContinuationJoin = false
                appendCommaContinuationText(sourceText, clean)
            }
            protoEvent == AssistantDoubaoProto.SourceEnd -> mergeFinalText(sourceText, clean)
            else -> appendDeltaText(sourceText, clean)
        }
        logTranscriptEvent(
            kind = "source",
            protoEvent = protoEvent,
            final = false,
            newTurn = newTurn
        )
        return transcript(final = false)
    }

    fun applyTranslation(text: String, protoEvent: Int): AssistantTranslationTranscript? {
        val clean = text.trim()
        if (clean.isBlank()) return null
        val newTurn = ensureOpenTurn(forceNew = false, allowCommaContinuation = false)
        val final = protoEvent == AssistantDoubaoProto.TranslationEnd
        translatedText = when {
            translationNeedsContinuationJoin -> {
                translationNeedsContinuationJoin = false
                appendCommaContinuationText(translatedText, clean)
            }
            final -> mergeFinalText(translatedText, clean)
            else -> appendDeltaText(translatedText, clean)
        }
        if (final) closeTurn()
        logTranscriptEvent(
            kind = "translation",
            protoEvent = protoEvent,
            final = final,
            newTurn = newTurn
        )
        return transcript(final)
    }

    private fun ensureOpenTurn(forceNew: Boolean, allowCommaContinuation: Boolean): Boolean {
        if (!forceNew && currentTurnId.isNotBlank() && !turnClosed) return false
        if (allowCommaContinuation && resumeCommaTurnWithinWindow()) return false
        currentTurnId = "turn-${UUID.randomUUID()}"
        sourceText = ""
        translatedText = ""
        turnClosed = false
        commaCompletedAtMillis = null
        continuationGapMillis = null
        sourceNeedsContinuationJoin = false
        translationNeedsContinuationJoin = false
        return true
    }

    private fun resumeCommaTurnWithinWindow(): Boolean {
        if (!turnClosed || currentTurnId.isBlank()) return false
        val completedAt = commaCompletedAtMillis ?: return false
        val gapMillis = clockMillis() - completedAt
        if (gapMillis !in 0L..MaxCommaContinuationGapMillis) return false
        turnClosed = false
        commaCompletedAtMillis = null
        continuationGapMillis = gapMillis
        sourceNeedsContinuationJoin = true
        translationNeedsContinuationJoin = true
        return true
    }

    private fun closeTurn() {
        turnClosed = true
        commaCompletedAtMillis = if (sourceText.endsWithComma() || translatedText.endsWithComma()) {
            clockMillis()
        } else {
            null
        }
    }

    private fun transcript(final: Boolean) = AssistantTranslationTranscript(
        id = currentTurnId,
        speaker = speaker,
        sourceLanguage = sourceLanguage,
        sourceText = sourceText,
        translatedLanguage = targetLanguage,
        translatedText = translatedText,
        final = final
    )

    private fun logTranscriptEvent(
        kind: String,
        protoEvent: Int,
        final: Boolean,
        newTurn: Boolean
    ) {
        log(
            "event=doubao_transcript direction=$speaker kind=$kind " +
                "proto=${doubaoEventName(protoEvent)} final=$final newTurn=$newTurn " +
                "commaContinuation=${continuationGapMillis != null} " +
                "continuationGapMs=${continuationGapMillis ?: -1L} " +
                "pendingComma=${commaCompletedAtMillis != null} " +
                "turnTail=${currentTurnId.takeLast(8)} sourceLen=${sourceText.length} " +
                "translatedLen=${translatedText.length} sourceHash=${sourceText.logHash()} " +
                "translatedHash=${translatedText.logHash()}"
        )
    }

    private companion object {
        const val LogTag = "TranslationSubtitle"
        const val MaxCommaContinuationGapMillis = 5_000L
    }
}

private fun appendCommaContinuationText(current: String, next: String): String {
    if (current.isBlank()) return next
    val separator = if (current.endsWith(',') && next.isNotBlank()) " " else ""
    return current + separator + next
}

private fun String.endsWithComma(): Boolean = endsWith(',') || endsWith('，')

internal fun appendDeltaText(current: String, delta: String): String {
    if (current.isBlank()) return delta
    if (delta.isBlank() || delta == current || current.endsWith(delta)) return current
    if (delta.startsWith(current)) return delta
    if (current.contains(delta)) return current
    val overlap = longestSuffixPrefixOverlap(current, delta)
    return current + delta.drop(overlap)
}

private fun mergeFinalText(current: String, finalText: String): String =
    if (finalText.length >= current.length || current.isBlank()) {
        finalText
    } else {
        appendDeltaText(current, finalText)
    }

private fun longestSuffixPrefixOverlap(current: String, delta: String): Int {
    val max = minOf(current.length, delta.length)
    for (length in max downTo 1) {
        if (current.endsWith(delta.take(length))) return length
    }
    return 0
}

private fun doubaoEventName(event: Int): String = when (event) {
    AssistantDoubaoProto.SourceStart -> "SourceStart"
    AssistantDoubaoProto.SourceResponse -> "SourceResponse"
    AssistantDoubaoProto.SourceEnd -> "SourceEnd"
    AssistantDoubaoProto.TranslationStart -> "TranslationStart"
    AssistantDoubaoProto.TranslationResponse -> "TranslationResponse"
    AssistantDoubaoProto.TranslationEnd -> "TranslationEnd"
    AssistantDoubaoProto.TtsResponse -> "TtsResponse"
    else -> event.toString()
}

private fun String.logHash(): String = Integer.toHexString(hashCode())
