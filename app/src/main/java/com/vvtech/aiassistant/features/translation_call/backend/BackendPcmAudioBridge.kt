package com.vvtech.aiassistant.features.translation_call.backend

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal interface BackendPcmAudioBridge {
    fun start(onPcm16: (ByteArray) -> Unit, onError: (String) -> Unit)
    fun play(audio: BackendRealtimeEvent.TranslatedAudio)
    fun setMuted(muted: Boolean)
    fun setSpeakerEnabled(enabled: Boolean)
    fun close()
}

internal class AndroidBackendPcmAudioBridge(
    context: Context
) : BackendPcmAudioBridge {
    private val appContext = context.applicationContext
    private val captureExecutor = Executors.newSingleThreadExecutor()
    private val playbackExecutor = Executors.newSingleThreadExecutor()
    private val active = AtomicBoolean()
    @Volatile private var muted = false
    @Volatile private var speakerEnabled = true
    private var recorder: AudioRecord? = null
    private var player: AudioTrack? = null
    private var playerSampleRate = 0
    private var lastPlaybackSequence = Long.MIN_VALUE

    override fun start(onPcm16: (ByteArray) -> Unit, onError: (String) -> Unit) {
        if (!active.compareAndSet(false, true)) return
        if (
            ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            active.set(false)
            onError("缺少麦克风权限")
            return
        }
        configureAudioRoute(speakerEnabled)
        captureExecutor.execute { capture(onPcm16, onError) }
    }

    override fun play(audio: BackendRealtimeEvent.TranslatedAudio) {
        if (!active.get() || audio.pcmLittleEndian.isEmpty()) return
        playbackExecutor.execute {
            if (audio.sequence >= 0 && audio.sequence <= lastPlaybackSequence) return@execute
            if (audio.sequence >= 0) lastPlaybackSequence = audio.sequence
            runCatching {
                val output = playerFor(audio.sampleRate)
                output.write(audio.pcmLittleEndian, 0, audio.pcmLittleEndian.size)
            }
        }
    }

    override fun setMuted(muted: Boolean) {
        this.muted = muted
    }

    override fun setSpeakerEnabled(enabled: Boolean) {
        speakerEnabled = enabled
        configureAudioRoute(enabled)
    }

    override fun close() {
        if (!active.getAndSet(false)) return
        runCatching { recorder?.stop() }
        runCatching { recorder?.release() }
        recorder = null
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        captureExecutor.shutdownNow()
        playbackExecutor.shutdownNow()
        releaseAudioRoute()
    }

    @SuppressLint("MissingPermission")
    private fun capture(onPcm16: (ByteArray) -> Unit, onError: (String) -> Unit) {
        try {
            val minimum = AudioRecord.getMinBufferSize(
                CaptureSampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            require(minimum > 0) { "麦克风缓冲区不可用" }
            val audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                CaptureSampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minimum, CaptureFrameBytes * 4)
            )
            recorder = audioRecord
            audioRecord.startRecording()
            val buffer = ByteArray(CaptureFrameBytes)
            while (active.get()) {
                val count = audioRecord.read(buffer, 0, buffer.size)
                if (count > 0 && !muted) onPcm16(buffer.copyOf(count))
            }
        } catch (error: Exception) {
            if (active.getAndSet(false)) {
                onError(error.message ?: "麦克风采集失败")
            }
        }
    }

    private fun playerFor(sampleRate: Int): AudioTrack {
        if (player != null && playerSampleRate == sampleRate) return requireNotNull(player)
        runCatching { player?.stop() }
        runCatching { player?.release() }
        val minimum = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        require(minimum > 0) { "播放缓冲区不可用" }
        val next = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minimum, sampleRate / 2))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        next.play()
        player = next
        playerSampleRate = sampleRate
        return next
    }

    private fun configureAudioRoute(enabled: Boolean) {
        val manager = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        manager.isSpeakerphoneOn = enabled
    }

    private fun releaseAudioRoute() {
        val manager = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        manager.mode = AudioManager.MODE_NORMAL
        manager.isSpeakerphoneOn = false
    }

    private companion object {
        const val CaptureSampleRate = 16_000
        const val CaptureFrameBytes = 640
    }
}
