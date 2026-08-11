package com.vvtech.aiassistant.features.assistant.speech

import android.content.Context
import android.media.AudioFocusRequest
import android.media.AudioManager
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.concurrent.atomic.AtomicBoolean

internal class TtsAudioFocusController(
    context: Context
) {
    private val audioManager = context.applicationContext
        .getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val active = AtomicBoolean(false)
    private var focusRequest: AudioFocusRequest? = null

    fun acquire(reason: String): Int {
        val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(TtsAudioAttributes.build())
            .setAcceptsDelayedFocusGain(false)
            .setOnAudioFocusChangeListener { change ->
                AppFileLogger.i(TAG, "TTS_DIAG AudioFocus change=${focusChangeName(change)} reason=$reason")
            }
            .build()
            .also { focusRequest = it }
        val result = audioManager.requestAudioFocus(request)
        active.set(result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        AppFileLogger.i(TAG, "TTS_DIAG AudioFocus result=${resultName(result)} reason=$reason")
        if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            AppFileLogger.w(TAG, "TTS_DIAG playback exception stage=audio_focus_denied result=${resultName(result)} reason=$reason")
        }
        return result
    }

    fun release(reason: String) {
        val request = focusRequest
        if (request == null) {
            if (active.getAndSet(false)) {
                AppFileLogger.i(TAG, "TTS_DIAG AudioFocus release skipped reason=$reason request=null")
            }
            return
        }
        if (active.getAndSet(false)) {
            val result = audioManager.abandonAudioFocusRequest(request)
            AppFileLogger.i(TAG, "TTS_DIAG AudioFocus released result=${resultName(result)} reason=$reason")
        }
    }

    companion object {
        private const val TAG = "TtsAudioFocusController"

        fun resultName(result: Int): String =
            when (result) {
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED -> "AUDIOFOCUS_REQUEST_GRANTED"
                AudioManager.AUDIOFOCUS_REQUEST_FAILED -> "AUDIOFOCUS_REQUEST_FAILED"
                AudioManager.AUDIOFOCUS_REQUEST_DELAYED -> "AUDIOFOCUS_REQUEST_DELAYED"
                else -> "AUDIOFOCUS_REQUEST_$result"
            }

        private fun focusChangeName(change: Int): String =
            when (change) {
                AudioManager.AUDIOFOCUS_GAIN -> "AUDIOFOCUS_GAIN"
                AudioManager.AUDIOFOCUS_LOSS -> "AUDIOFOCUS_LOSS"
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> "AUDIOFOCUS_LOSS_TRANSIENT"
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> "AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK"
                else -> "AUDIOFOCUS_CHANGE_$change"
            }
    }
}
