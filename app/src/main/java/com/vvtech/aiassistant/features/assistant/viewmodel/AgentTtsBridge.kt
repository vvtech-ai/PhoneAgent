package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.logging.AppFileLogger

import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant.speech.AudioPlayer
import com.vvtech.aiassistant.features.assistant.speech.DEFAULT_TTS_SPEAKER
import com.vvtech.aiassistant.features.assistant.speech.TtsApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentLinkedQueue

private const val TAG = "AgentTtsBridge"
private const val SENTENCE_BREAK_THRESHOLD = 80
private const val FIRST_CHUNK_TIMEOUT_MS = 800L

class AgentTtsBridge(
    private val ttsClient: TtsApiClient,
    private val audioPlayer: AudioPlayer,
    private val scope: CoroutineScope,
    private val speaker: String = DEFAULT_TTS_SPEAKER,
    private val languageCodeProvider: () -> String = { DefaultVoiceLanguageCode }
) {

    private data class CompletionCallbacks(
        val onComplete: (() -> Unit)?,
        val onError: (() -> Unit)?
    )

    var onAllPlaybackComplete: (() -> Unit)? = null
    var onPlaybackFailed: ((Throwable?) -> Unit)? = null
    var onPlaybackStarted: (() -> Unit)? = null
    var onBeforeSentenceSynthesis: ((String) -> Unit)? = null
    var onBeforeAudioEnqueue: (() -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val buffer = StringBuilder()
    private val pendingSentences = ConcurrentLinkedQueue<String>()
    private val oneShotCompletionCallbacks = ConcurrentLinkedQueue<CompletionCallbacks>()
    private var synthesisJob: Job? = null
    private var active = false
    private var activeLanguageCode = DefaultVoiceLanguageCode

    init {
        audioPlayer.onPlaybackComplete = {
            AppFileLogger.d(TAG, "audioPlayer playbackComplete pendingSentences=${pendingSentences.size}")
            if (pendingSentences.isEmpty() && !isSynthesizing()) {
                notifyPlaybackComplete()
            }
        }
        audioPlayer.onPlaybackStarted = {
            if (active) {
                onPlaybackStarted?.invoke()
            }
        }
        audioPlayer.onSegmentPlaybackStarting = {
            if (active) {
                onBeforeAudioEnqueue?.invoke()
                onPlaybackStarted?.invoke()
            }
        }
    }

    fun feedTextDelta(delta: String) {
        if (delta.isEmpty()) return
        activeLanguageCode = VoiceLanguage.fromCode(languageCodeProvider()).code
        buffer.append(delta)
        AppFileLogger.d(TAG, "feedTextDelta: deltaLength=${delta.length} bufferLen=${buffer.length}")
        drainSentences()
        scheduleFirstChunkFlush()
    }

    fun feedSignalText(
        text: String,
        languageCode: String = languageCodeProvider(),
        onComplete: (() -> Unit)? = null,
        onError: (() -> Unit)? = null
    ) {
        if (text.isBlank()) return
        activeLanguageCode = VoiceLanguage.fromCode(languageCode).code
        AppFileLogger.d(TAG, "feedSignalText len=${text.length}")
        if (onComplete != null || onError != null) {
            oneShotCompletionCallbacks.add(CompletionCallbacks(onComplete = onComplete, onError = onError))
        }
        enqueueSentence(text)
    }

    fun flush() {
        val remaining = buffer.toString().trim()
        buffer.clear()
        if (remaining.isNotBlank()) {
            AppFileLogger.d(TAG, "flush remaining len=${remaining.length}")
            enqueueSentence(remaining)
        }
    }

    fun interrupt() {
        AppFileLogger.d(TAG, "TTS_DIAG bridge interrupt active=$active pending=${pendingSentences.size}")
        closeRealtime("interrupt")
    }

    fun closeRealtime(reason: String) {
        AppFileLogger.i(
            TAG,
            "TTS_DIAG bridge closeRealtime reason=$reason active=$active pending=${pendingSentences.size} " +
                "bufferLen=${buffer.length} synthesizing=${isSynthesizing()}"
        )
        active = false
        mainHandler.removeCallbacks(firstChunkFlushRunnable)
        buffer.clear()
        pendingSentences.clear()
        oneShotCompletionCallbacks.clear()
        synthesisJob?.cancel()
        synthesisJob = null
        ttsClient.close(reason)
        audioPlayer.interrupt()
    }

    fun release() {
        closeRealtime("release")
        audioPlayer.onSegmentPlaybackStarting = null
        onAllPlaybackComplete = null
        onPlaybackFailed = null
        onPlaybackStarted = null
        onBeforeSentenceSynthesis = null
        onBeforeAudioEnqueue = null
    }

    private fun drainSentences() {
        var drained = false
        while (true) {
            val text = buffer.toString()
            val breakIdx = findSentenceBreak(text)
            if (breakIdx < 0) break
            val sentence = text.substring(0, breakIdx + 1).trim()
            buffer.delete(0, breakIdx + 1)
            if (sentence.isNotBlank()) {
                enqueueSentence(sentence)
                drained = true
            }
        }
        if (drained) mainHandler.removeCallbacks(firstChunkFlushRunnable)
    }

    private fun findSentenceBreak(text: String): Int {
        for (i in text.indices) {
            val ch = text[i]
            if (ch == '。' || ch == '！' || ch == '？' || ch == '\n'
                || ch == '.' || ch == '!' || ch == '?') {
                return i
            }
        }
        if (text.length > SENTENCE_BREAK_THRESHOLD) {
            for (i in text.indices) {
                val ch = text[i]
                if (ch == '，' || ch == '、' || ch == '；'
                    || ch == ',' || ch == ';') {
                    return i
                }
            }
        }
        return -1
    }

    private fun scheduleFirstChunkFlush() {
        mainHandler.removeCallbacks(firstChunkFlushRunnable)
        if (buffer.isNotEmpty() && pendingSentences.isEmpty() && !isSynthesizing()) {
            mainHandler.postDelayed(firstChunkFlushRunnable, FIRST_CHUNK_TIMEOUT_MS)
        }
    }

    private val firstChunkFlushRunnable = Runnable {
        val text = buffer.toString().trim()
        if (text.isNotBlank() && pendingSentences.isEmpty()) {
            AppFileLogger.d(TAG, "firstChunkFlush timeout textLength=${text.length}")
            buffer.clear()
            enqueueSentence(text)
        }
    }

    private fun enqueueSentence(sentence: String) {
        AppFileLogger.d(TAG, "enqueueSentence textLength=${sentence.length} pending=${pendingSentences.size}")
        pendingSentences.add(sentence)
        active = true
        synthesizeNext()
    }

    private fun isSynthesizing(): Boolean = synthesisJob?.isActive == true

    private fun synthesizeNext() {
        if (isSynthesizing()) return
        val sentence = pendingSentences.poll() ?: return
        if (!active) return
        val languageCode = activeLanguageCode
        val selectedSpeaker = speakerForLanguage(languageCode)
        val spokenSentence = normalizeTtsSentenceForLanguage(sentence, languageCode)
        AppFileLogger.i(
            TAG,
            "TTS_DIAG TTS request started textLen=${spokenSentence.length} " +
                "language=$languageCode speaker=$selectedSpeaker format=${ttsClient.audioFormat} " +
                "remaining=${pendingSentences.size}"
        )
        onBeforeSentenceSynthesis?.invoke(spokenSentence)
        synthesisJob = scope.launch {
            ttsClient.synthesize(
                text = spokenSentence,
                speaker = selectedSpeaker,
                onAudioChunk = { chunk ->
                    if (active) {
                        AppFileLogger.i(
                            TAG,
                            "TTS_DIAG TTS audio received bytes=${chunk.size} " +
                                "format=${ttsClient.audioFormat} textLen=${spokenSentence.length}"
                        )
                        audioPlayer.enqueue(chunk, ttsClient.audioFormat)
                    } else {
                        AppFileLogger.i(
                            TAG,
                            "TTS_DIAG TTS audio received dropped reason=bridge_inactive bytes=${chunk.size} " +
                                "format=${ttsClient.audioFormat}"
                        )
                    }
                },
                onComplete = {
                    AppFileLogger.i(
                        TAG,
                        "TTS_DIAG TTS returned success textLen=${spokenSentence.length} " +
                            "pending=${pendingSentences.size} playerPlaying=${audioPlayer.isPlaying()}"
                    )
                    synthesisJob = null
                    if (active) {
                        synthesizeNext()
                    }
                    if (pendingSentences.isEmpty() && !audioPlayer.isPlaying()) {
                        notifyPlaybackComplete()
                    }
                },
                onError = { throwable ->
                    AppFileLogger.e(
                        TAG,
                        "TTS_DIAG TTS returned failure textLen=${spokenSentence.length} " +
                            "message=${throwable.message}",
                        throwable
                    )
                    synthesisJob = null
                    if (active) {
                        synthesizeNext()
                    }
                    if (pendingSentences.isEmpty() && !audioPlayer.isPlaying()) {
                        notifyPlaybackComplete(throwable)
                    }
                }
            )
        }
    }

    private fun speakerForLanguage(languageCode: String): String {
        return when (VoiceLanguage.fromCode(languageCode)) {
            VoiceLanguage.English -> ENGLISH_TTS_SPEAKER
            else -> speaker
        }
    }

    private fun notifyPlaybackComplete(error: Throwable? = null) {
        mainHandler.post {
            val callbacks = mutableListOf<CompletionCallbacks>()
            while (true) {
                callbacks.add(oneShotCompletionCallbacks.poll() ?: break)
            }
            if (callbacks.isNotEmpty()) {
                callbacks.forEach { callback ->
                    if (error == null) {
                        callback.onComplete?.invoke()
                    } else {
                        (callback.onError ?: callback.onComplete)?.invoke()
                    }
                }
                return@post
            }
            if (error == null) {
                onAllPlaybackComplete?.invoke()
            } else {
                val failureCallback = onPlaybackFailed
                if (failureCallback != null) {
                    failureCallback.invoke(error)
                } else {
                    onAllPlaybackComplete?.invoke()
                }
            }
        }
    }
}

private const val ENGLISH_TTS_SPEAKER = "Andre"

internal fun normalizeTtsSentenceForLanguage(
    sentence: String,
    languageCode: String
): String {
    if (VoiceLanguage.fromCode(languageCode) != VoiceLanguage.English) return sentence
    return normalizeEnglishTtsSentence(sentence)
}

private fun normalizeEnglishTtsSentence(sentence: String): String {
    var text = sanitizeUserFacingNetworkText(sentence, VoiceLanguage.English)
    text = text.replace(Regex("""\(\s*\d{4}-\d{1,2}-\d{1,2}[^)]*\)"""), "")
    text = text.replace(Regex("""\b(\d{1,2})\s*p\.\s*m\.""", RegexOption.IGNORE_CASE)) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(if (hour > 12) hour - 12 else hour)} PM"
    }
    text = text.replace(Regex("""\b(\d{1,2})\s*a\.\s*m\.""", RegexOption.IGNORE_CASE)) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(if (hour == 0) 12 else hour)} AM"
    }
    text = text.replace(Regex("""\b(\d{1,2}):00\b""")) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        val displayHour = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        val suffix = if (hour >= 12) "PM" else "AM"
        "${numberToEnglishWords(displayHour)} $suffix"
    }
    text = text.replace(Regex("""(?:下午|晚上|今晚)\s*(\d{1,2})\s*点""")) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(if (hour > 12) hour - 12 else hour)} PM"
    }
    text = text.replace(Regex("""(?:上午|早上)\s*(\d{1,2})\s*点""")) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(if (hour == 0) 12 else hour)} AM"
    }
    text = text.replace(Regex("""\b(\d{1,2})\s*点""")) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        val displayHour = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        val suffix = if (hour >= 12) "PM" else "AM"
        "${numberToEnglishWords(displayHour)} $suffix"
    }
    text = text.replace(Regex("""\b(\d{1,2}):([0-5]\d)\b""")) { match ->
        val hour = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        val minute = match.groupValues[2].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(hour)} ${numberToEnglishWords(minute)}"
    }
    text = text.replace(Regex("""\bending in\s+(\d{3,4})\b""", RegexOption.IGNORE_CASE)) { match ->
        "ending in ${digitsToEnglishWords(match.groupValues[1])}"
    }
    text = text.replace(Regex("""\b(\d+)\s*(?:people|persons|guests)\b""", RegexOption.IGNORE_CASE)) { match ->
        val count = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "${numberToEnglishWords(count)} people"
    }
    text = text.replace(Regex("""([一二三四五六七八九十两俩]+)\s*(?:people|persons|guests)\b""")) { match ->
        "${chineseNumberToEnglishWords(match.groupValues[1]) ?: match.groupValues[1]} people"
    }
    text = text.replace(Regex("""\bNo\.\s*(\d+)\b""", RegexOption.IGNORE_CASE)) { match ->
        val number = match.groupValues[1].toIntOrNull() ?: return@replace match.value
        "number ${numberToEnglishWords(number)}"
    }
    text = text.replace(Regex("""\b\d{3,}\b""")) { match ->
        digitsToEnglishWords(match.value)
    }
    text = text.replace(Regex("""\b\d{1,2}\b""")) { match ->
        numberToEnglishWords(match.value.toInt())
    }
    return text
        .replace(Regex("""[ \t\u00A0]+"""), " ")
        .trim()
}

private fun digitsToEnglishWords(digits: String): String =
    digits.mapNotNull { digitToEnglishWord(it) }.joinToString(" ")

private fun digitToEnglishWord(char: Char): String? = when (char) {
    '0' -> "zero"
    '1' -> "one"
    '2' -> "two"
    '3' -> "three"
    '4' -> "four"
    '5' -> "five"
    '6' -> "six"
    '7' -> "seven"
    '8' -> "eight"
    '9' -> "nine"
    else -> null
}

private fun numberToEnglishWords(number: Int): String {
    if (number < 0) return "minus ${numberToEnglishWords(-number)}"
    if (number < 20) return SmallNumberWords[number]
    if (number < 100) {
        val tens = TensNumberWords[number / 10]
            ?: return number.toString().mapNotNull { digitToEnglishWord(it) }.joinToString(" ")
        val ones = number % 10
        return if (ones == 0) tens else "$tens ${SmallNumberWords[ones]}"
    }
    if (number < 1000) {
        val hundreds = number / 100
        val rest = number % 100
        return if (rest == 0) {
            "${SmallNumberWords[hundreds]} hundred"
        } else {
            "${SmallNumberWords[hundreds]} hundred ${numberToEnglishWords(rest)}"
        }
    }
    return number.toString().mapNotNull { digitToEnglishWord(it) }.joinToString(" ")
}

private fun chineseNumberToEnglishWords(text: String): String? =
    chineseNumberToInt(text)?.let(::numberToEnglishWords)

private fun chineseNumberToInt(text: String): Int? {
    val normalized = text.replace("两", "二").replace("俩", "二")
    if (normalized.isBlank()) return null
    if (normalized == "十") return 10
    if (normalized.contains("十")) {
        val parts = normalized.split("十", limit = 2)
        val tens = parts.getOrNull(0)
            ?.takeIf { it.isNotBlank() }
            ?.let(::singleChineseDigitToInt)
            ?: 1
        val ones = parts.getOrNull(1)
            ?.takeIf { it.isNotBlank() }
            ?.let(::singleChineseDigitToInt)
            ?: 0
        return tens * 10 + ones
    }
    return singleChineseDigitToInt(normalized)
}

private fun singleChineseDigitToInt(text: String): Int? = when (text) {
    "零" -> 0
    "一" -> 1
    "二" -> 2
    "三" -> 3
    "四" -> 4
    "五" -> 5
    "六" -> 6
    "七" -> 7
    "八" -> 8
    "九" -> 9
    else -> null
}

private val SmallNumberWords = listOf(
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen"
)

private val TensNumberWords = mapOf(
    2 to "twenty",
    3 to "thirty",
    4 to "forty",
    5 to "fifty",
    6 to "sixty",
    7 to "seventy",
    8 to "eighty",
    9 to "ninety"
)
