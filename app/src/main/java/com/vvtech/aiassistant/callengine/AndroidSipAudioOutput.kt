package com.vvtech.aiassistant.callengine

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack

internal class AndroidSipAudioOutput(
    context: Context,
    initialSpeakerEnabled: Boolean,
    private val onFailure: (String) -> Unit
) : AutoCloseable {
    private val appContext = context.applicationContext
    private var speakerEnabled = initialSpeakerEnabled
    private var track: AudioTrack? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    fun start() {
        configureAudioRoute()
        val minBuffer = AudioTrack.getMinBufferSize(
            SampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        track = AudioTrack.Builder()
            .setAudioAttributes(attributes())
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuffer, FrameSamples * 8))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        requestAudioFocus()
        runCatching { track?.play() }
            .onFailure { onFailure(it.message ?: "音频播放启动失败") }
    }

    fun play(pcm16k: ShortArray) {
        val output = track ?: return
        runCatching {
            if (output.playState != AudioTrack.PLAYSTATE_PLAYING) output.play()
            output.write(pcm16k, 0, pcm16k.size, AudioTrack.WRITE_BLOCKING)
        }.onFailure { onFailure(it.message ?: "音频播放失败") }
    }

    fun setSpeakerEnabled(enabled: Boolean) {
        speakerEnabled = enabled
        configureAudioRoute()
    }

    override fun close() {
        runCatching { track?.pause() }
        runCatching { track?.flush() }
        runCatching { track?.release() }
        track = null
        val manager = audioManager()
        audioFocusRequest?.let { runCatching { manager.abandonAudioFocusRequest(it) } }
        audioFocusRequest = null
        manager.mode = AudioManager.MODE_NORMAL
        @Suppress("DEPRECATION")
        runCatching { manager.isSpeakerphoneOn = false }
    }

    private fun configureAudioRoute() {
        val manager = audioManager()
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        @Suppress("DEPRECATION")
        runCatching { manager.isSpeakerphoneOn = speakerEnabled }
    }

    private fun requestAudioFocus() {
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setAudioAttributes(attributes())
            .setOnAudioFocusChangeListener { }
            .build()
        audioFocusRequest = request
        audioManager().requestAudioFocus(request)
    }

    private fun audioManager(): AudioManager =
        appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun attributes() = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private companion object {
        const val SampleRate = 16_000
        const val FrameSamples = 320
    }
}
