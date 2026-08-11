package com.vvtech.aiassistant.features.assistant.speech

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import java.util.concurrent.atomic.AtomicBoolean

internal object TtsAudioAttributes {
    fun build(): AudioAttributes {
        val builder = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_SYSTEM)
        }
        return builder.build()
    }

    fun volumeControlStream(): Int = AudioManager.STREAM_MUSIC

    fun routePolicyName(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) "media_system_capture_only" else "media"

    fun shouldUseVoiceCommunicationUsage(): Boolean = false
}

internal object TtsAudioModeController {
    private val lock = Any()
    private var activeCount = 0
    private var savedMode: Int? = null

    fun shouldUseCommunicationMode(): Boolean =
        TtsAudioAttributes.shouldUseVoiceCommunicationUsage()

    fun enter(context: Context): TtsAudioModeSession? {
        if (!shouldUseCommunicationMode()) {
            return null
        }
        val audioManager = context.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as AudioManager
        synchronized(lock) {
            val before = audioManager.mode
            if (activeCount == 0) {
                savedMode = before
                if (before != AudioManager.MODE_IN_COMMUNICATION) {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                }
            }
            activeCount += 1
        }
        return TtsAudioModeSession {
            exit(context.applicationContext)
        }
    }

    fun isCommunicationModeActive(): Boolean =
        synchronized(lock) { activeCount > 0 }

    fun modeName(mode: Int): String =
        when (mode) {
            AudioManager.MODE_NORMAL -> "MODE_NORMAL"
            AudioManager.MODE_RINGTONE -> "MODE_RINGTONE"
            AudioManager.MODE_IN_CALL -> "MODE_IN_CALL"
            AudioManager.MODE_IN_COMMUNICATION -> "MODE_IN_COMMUNICATION"
            else -> "MODE_$mode"
        }

    private fun exit(context: Context) {
        if (!shouldUseCommunicationMode()) {
            return
        }
        val audioManager = context.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as AudioManager
        synchronized(lock) {
            if (activeCount <= 0) {
                activeCount = 0
                savedMode = null
                return
            }
            activeCount -= 1
            val before = audioManager.mode
            val targetMode = savedMode ?: AudioManager.MODE_NORMAL
            if (activeCount == 0) {
                if (before == AudioManager.MODE_IN_COMMUNICATION) {
                    audioManager.mode = targetMode
                }
                savedMode = null
            }
        }
    }
}

internal class TtsAudioModeSession internal constructor(
    private val onClose: () -> Unit
) : AutoCloseable {
    private val closed = AtomicBoolean(false)

    override fun close() {
        if (closed.compareAndSet(false, true)) {
            onClose()
        }
    }
}
