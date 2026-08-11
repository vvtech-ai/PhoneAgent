package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/**
 * One-shot speech recognizer used to mirror spoken turns into the on-screen
 * clarification bubbles while the RTC voice session stays active.
 *
 * Some Huawei devices expose a fake recognition service that never produces
 * usable callbacks. To avoid hanging on "正在听你说", this wrapper:
 * 1. only uses on-device recognition when Android explicitly reports support
 * 2. falls back to the regular recognizer if on-device creation is unsupported
 * 3. adds a startup watchdog so the UI can fall back to RTC subtitles
 */
class AndroidSpeechRecognizer(
    private val appContext: Context
) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: ((SpeechRecognitionEvent) -> Unit)? = null
    private var sessionToken = 0L
    private var sessionSettled = false

    fun start(
        languageCode: String = DefaultVoiceLanguageCode,
        onEvent: (SpeechRecognitionEvent) -> Unit
    ) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { start(languageCode, onEvent) }
            return
        }
        startOnMain(languageCode, onEvent)
    }

    private fun startOnMain(
        languageCode: String,
        onEvent: (SpeechRecognitionEvent) -> Unit
    ) {
        eventSink = onEvent
        val normalizedLanguageCode = VoiceLanguage.fromCode(languageCode).code
        val useOnDevice = shouldUseOnDeviceRecognizer()
        if (!useOnDevice && !SpeechRecognizer.isRecognitionAvailable(appContext)) {
            onEvent(SpeechRecognitionEvent.Error("当前设备不可用系统语音识别"))
            return
        }

        sessionToken += 1L
        sessionSettled = false
        createRecognizer(useOnDevice)

        val token = sessionToken
        mainHandler.postDelayed(
            {
                if (token != sessionToken || sessionSettled) {
                    return@postDelayed
                }
                runCatching {
                    speechRecognizer?.startListening(buildIntent(useOnDevice, normalizedLanguageCode))
                }.onFailure { throwable ->
                    settleWithError(throwable.message ?: "语音识别启动失败", token)
                }
            },
            START_DELAY_MS
        )
        mainHandler.postDelayed(
            {
                if (token != sessionToken || sessionSettled) {
                    return@postDelayed
                }
                settleWithError(startupTimeoutMessage(useOnDevice), token)
            },
            STARTUP_TIMEOUT_MS
        )
    }

    fun stop() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { stop() }
            return
        }
        speechRecognizer?.stopListening()
    }

    fun cancel() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { cancel() }
            return
        }
        cancelOnMain()
    }

    private fun cancelOnMain() {
        sessionToken += 1L
        sessionSettled = true
        speechRecognizer?.cancel()
        releaseInternal()
    }

    fun release() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { release() }
            return
        }
        cancelOnMain()
    }

    private fun createRecognizer(useOnDevice: Boolean) {
        releaseInternal()
        speechRecognizer = createRecognizerInstance(useOnDevice).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    eventSink?.invoke(SpeechRecognitionEvent.Ready)
                }

                override fun onBeginningOfSpeech() {
                    eventSink?.invoke(SpeechRecognitionEvent.Listening)
                }

                override fun onRmsChanged(rmsdB: Float) = Unit

                override fun onBufferReceived(buffer: ByteArray?) = Unit

                override fun onEndOfSpeech() {
                    eventSink?.invoke(SpeechRecognitionEvent.Processing)
                }

                override fun onError(error: Int) {
                    settleWithError(errorMessage(error), sessionToken)
                }

                override fun onResults(results: Bundle?) {
                    val text = extractTopResult(results)
                    if (text.isBlank()) {
                        settleWithError("这次没有听清，你再说一遍", sessionToken)
                    } else {
                        sessionSettled = true
                        eventSink?.invoke(SpeechRecognitionEvent.FinalResult(text))
                        releaseInternal()
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = extractTopResult(partialResults)
                    if (partial.isNotBlank()) {
                        eventSink?.invoke(SpeechRecognitionEvent.PartialResult(partial))
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) = Unit
            })
        }
    }

    private fun buildIntent(useOnDevice: Boolean, languageCode: String): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageCode)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, languageCode)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            if (useOnDevice) {
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
        }
    }

    private fun extractTopResult(bundle: Bundle?): String {
        val results = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return results?.firstOrNull()?.trim().orEmpty()
    }

    private fun settleWithError(message: String, token: Long) {
        if (token != sessionToken || sessionSettled) {
            return
        }
        sessionSettled = true
        eventSink?.invoke(SpeechRecognitionEvent.Error(message))
        releaseInternal()
    }

    private fun releaseInternal() {
        runCatching { speechRecognizer?.destroy() }
        speechRecognizer = null
    }

    private fun shouldUseOnDeviceRecognizer(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                SpeechRecognizer.isOnDeviceRecognitionAvailable(appContext)
    }

    private fun isFakeRecognitionService(): Boolean {
        val service = runCatching {
            Settings.Secure.getString(appContext.contentResolver, "voice_recognition_service")
        }.getOrNull().orEmpty()
        return service.contains("FakeRecognitionService", ignoreCase = true)
    }

    private fun startupTimeoutMessage(useOnDevice: Boolean): String {
        return if (useOnDevice) {
            "本机语音识别启动超时，正在等待实时字幕兜底"
        } else if (isFakeRecognitionService()) {
            "当前系统语音识别服务不可用，正在等待实时字幕兜底"
        } else {
            "系统语音识别服务未就绪，正在等待实时字幕兜底"
        }
    }

    private fun errorMessage(code: Int): String {
        return when (code) {
            SpeechRecognizer.ERROR_AUDIO -> "语音输入异常，请再试一次"
            SpeechRecognizer.ERROR_CLIENT -> "语音识别服务暂时不可用"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "没有拿到录音权限"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音识别网络异常"
            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "这次没有听清，你再说一遍"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "我还在听上一句，稍等一下"
            SpeechRecognizer.ERROR_SERVER -> "语音识别服务暂时不可用"
            else -> "语音识别失败，错误码 $code"
        }
    }

    private fun createRecognizerInstance(useOnDevice: Boolean): SpeechRecognizer {
        if (!useOnDevice) {
            return SpeechRecognizer.createSpeechRecognizer(appContext)
        }
        return runCatching {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(appContext)
        }.getOrElse {
            SpeechRecognizer.createSpeechRecognizer(appContext)
        }
    }

    private companion object {
        const val START_DELAY_MS = 220L
        const val STARTUP_TIMEOUT_MS = 2600L
    }
}

sealed interface SpeechRecognitionEvent {
    object Ready : SpeechRecognitionEvent
    object Listening : SpeechRecognitionEvent
    object Processing : SpeechRecognitionEvent
    data class PartialResult(val text: String) : SpeechRecognitionEvent
    data class FinalResult(val text: String) : SpeechRecognitionEvent
    data class Error(val message: String) : SpeechRecognitionEvent
}
