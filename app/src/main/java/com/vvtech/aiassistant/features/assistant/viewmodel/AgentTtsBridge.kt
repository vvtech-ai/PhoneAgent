package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.logging.AppFileLogger

import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.features.assistant.speech.AudioPlayer
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
    private val speaker: String = "zh_male_taocheng_uranus_bigtts"
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
        buffer.append(delta)
        AppFileLogger.d(TAG, "feedTextDelta: deltaLength=${delta.length} bufferLen=${buffer.length}")
        drainSentences()
        scheduleFirstChunkFlush()
    }

    fun feedSignalText(
        text: String,
        onComplete: (() -> Unit)? = null,
        onError: (() -> Unit)? = null
    ) {
        if (text.isBlank()) return
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
        AppFileLogger.i(
            TAG,
            "TTS_DIAG TTS request started textLen=${sentence.length} " +
                "speaker=$speaker format=${ttsClient.audioFormat} remaining=${pendingSentences.size}"
        )
        onBeforeSentenceSynthesis?.invoke(sentence)
        synthesisJob = scope.launch {
            ttsClient.synthesize(
                text = sentence,
                speaker = speaker,
                onAudioChunk = { chunk ->
                    if (active) {
                        AppFileLogger.i(
                            TAG,
                            "TTS_DIAG TTS audio received bytes=${chunk.size} " +
                                "format=${ttsClient.audioFormat} textLen=${sentence.length}"
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
                        "TTS_DIAG TTS returned success textLen=${sentence.length} " +
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
                        "TTS_DIAG TTS returned failure textLen=${sentence.length} " +
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
