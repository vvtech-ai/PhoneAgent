package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.vvtech.aiassistant.features.assistant.speech.TtsAudioAttributes
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Stable local TTS fallback for assistant replies.
 * We use device-side playback so assistant text is always spoken even when
 * the dialog SDK player does not actually output audio on a given device.
 */
class AssistantSpeechPlayer(
    context: Context
) {

    private data class PendingSpeakRequest(
        val text: String,
        val languageCode: String,
        val onStart: (() -> Unit)?,
        val onDone: (() -> Unit)?,
        val onError: (() -> Unit)?
    )

    private data class SpeakCallbacks(
        val onStart: (() -> Unit)?,
        val onDone: (() -> Unit)?,
        val onError: (() -> Unit)?
    )

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbacks = ConcurrentHashMap<String, SpeakCallbacks>()
    private var tts: TextToSpeech? = null
    private var ready = false
    private var warmedUp = false
    private var pendingRequest: PendingSpeakRequest? = null
    private val pendingInitTimeoutRunnable = Runnable {
        if (!ready && pendingRequest != null) {
            failPendingRequest()
        }
    }

    init {
        val explicitEngine = resolveAvailableTtsEngine()
        val initListener = TextToSpeech.OnInitListener { status ->
            if (status == TextToSpeech.SUCCESS) {
                mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
                ready = true
                tts?.setLanguage(Locale.SIMPLIFIED_CHINESE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    tts?.setAudioAttributes(TtsAudioAttributes.build())
                }
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        dispatchStartCallback(utteranceId)
                    }

                    override fun onDone(utteranceId: String?) {
                        dispatchCallback(utteranceId, success = true)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        dispatchCallback(utteranceId, success = false)
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        dispatchCallback(utteranceId, success = false)
                    }
                })
                pendingRequest?.let {
                    pendingRequest = null
                    speak(it.text, it.languageCode, it.onStart, it.onDone, it.onError)
                } ?: warmUpIfNeeded()
            } else {
                ready = false
                mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
                failPendingRequest()
            }
        }
        tts = if (explicitEngine.isNullOrBlank()) {
            TextToSpeech(appContext, initListener)
        } else {
            TextToSpeech(appContext, initListener, explicitEngine)
        }
    }

    fun speak(
        text: String,
        languageCode: String = DefaultVoiceLanguageCode,
        onStart: (() -> Unit)? = null,
        onDone: (() -> Unit)? = null,
        onError: (() -> Unit)? = onDone
    ) {
        val normalized = text.trim()
        if (normalized.isBlank()) {
            return
        }
        if (!ready) {
            pendingRequest = PendingSpeakRequest(normalized, languageCode, onStart, onDone, onError)
            mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
            mainHandler.postDelayed(pendingInitTimeoutRunnable, TtsInitTimeoutMillis)
            return
        }
        mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
        val languageResult = tts?.setLanguage(VoiceLanguage.fromCode(languageCode).locale)
        if (languageResult == TextToSpeech.LANG_MISSING_DATA || languageResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            dispatchRunnable(onError)
            return
        }
        val utteranceId = "assistant-${UUID.randomUUID()}"
        callbacks.clear()
        callbacks[utteranceId] = SpeakCallbacks(onStart = onStart, onDone = onDone, onError = onError)
        scheduleUtteranceTimeout(utteranceId, normalized)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val result = tts?.speak(normalized, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
            if (result != TextToSpeech.SUCCESS) {
                mainHandler.removeCallbacksAndMessages(utteranceId)
                callbacks.remove(utteranceId)
                dispatchRunnable(onError)
            }
        } else {
            @Suppress("DEPRECATION")
            val result = tts?.speak(normalized, TextToSpeech.QUEUE_FLUSH, null)
            if (result != TextToSpeech.SUCCESS) {
                mainHandler.removeCallbacksAndMessages(utteranceId)
                callbacks.remove(utteranceId)
                dispatchRunnable(onError)
            }
        }
    }

    fun stop() {
        pendingRequest = null
        mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
        callbacks.clear()
        mainHandler.removeCallbacksAndMessages(null)
        tts?.stop()
    }

    fun release() {
        pendingRequest = null
        mainHandler.removeCallbacks(pendingInitTimeoutRunnable)
        callbacks.clear()
        mainHandler.removeCallbacksAndMessages(null)
        ready = false
        warmedUp = false
        tts?.stop()
        tts?.shutdown()
        tts = null
    }

    private fun warmUpIfNeeded() {
        if (!ready || warmedUp) {
            return
        }
        warmedUp = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            tts?.playSilentUtterance(1L, TextToSpeech.QUEUE_ADD, "assistant-warmup")
        } else {
            @Suppress("DEPRECATION")
            tts?.playSilence(1L, TextToSpeech.QUEUE_ADD, null)
        }
    }

    private fun dispatchStartCallback(utteranceId: String?) {
        val entry = utteranceId?.let { callbacks[it] } ?: return
        dispatchRunnable(entry.onStart)
    }

    private fun dispatchCallback(utteranceId: String?, success: Boolean) {
        val entry = utteranceId?.let { callbacks.remove(it) } ?: return
        mainHandler.removeCallbacksAndMessages(utteranceId)
        dispatchRunnable(if (success) entry.onDone else entry.onError)
    }

    private fun failPendingRequest() {
        val request = pendingRequest ?: return
        pendingRequest = null
        dispatchRunnable(request.onError)
    }

    private fun scheduleUtteranceTimeout(utteranceId: String, text: String) {
        mainHandler.removeCallbacksAndMessages(utteranceId)
        val timeoutMillis = estimateSpeechTimeoutMillis(text)
        mainHandler.postAtTime(
            {
                val entry = callbacks.remove(utteranceId) ?: return@postAtTime
                dispatchRunnable(entry.onError)
            },
            utteranceId,
            SystemClock.uptimeMillis() + timeoutMillis
        )
    }

    private fun estimateSpeechTimeoutMillis(text: String): Long {
        val byLength = 1_500L + text.length * 140L
        return byLength.coerceIn(3_000L, 30_000L)
    }

    private fun resolveAvailableTtsEngine(): String? {
        val intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
        val services = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.packageManager.queryIntentServices(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.packageManager.queryIntentServices(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        val preferred = services
            .mapNotNull { it.serviceInfo?.packageName?.trim() }
            .firstOrNull { it.isNotBlank() }
        return preferred
    }

    private fun dispatchRunnable(callback: (() -> Unit)?) {
        if (callback == null) {
            return
        }
        mainHandler.post { callback.invoke() }
    }

    private companion object {
        const val TtsInitTimeoutMillis = 2_500L
    }
}
