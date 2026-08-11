package com.vvtech.aiassistant.features.assistant_recording

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import com.vvtech.aiassistant.data.repository.recording.CallRecordingPlaybackSource
import com.vvtech.aiassistant.logging.AppFileLogger
import java.lang.ref.WeakReference
import java.util.concurrent.atomic.AtomicLong

internal interface CallRecordingPlaybackEngine {
    fun beginLoading(onStopped: () -> Unit)
    fun finishLoading()
    fun play(
        source: CallRecordingPlaybackSource,
        onStarted: () -> Unit,
        onCompleted: () -> Unit,
        onFailed: () -> Unit,
        onPaused: () -> Unit,
        onStopped: () -> Unit,
    )
    fun pause(): Boolean
    fun resume(): Boolean
    fun stop()
    fun currentPositionMillis(): Long?
    fun durationMillis(): Long?
}

internal class CallRecordingPlayer(
    context: Context,
    private val callId: String,
) : CallRecordingPlaybackEngine {
    private val appContext = context.applicationContext
    private var player: MediaPlayer? = null
    private var onPaused: (() -> Unit)? = null
    private var onStopped: (() -> Unit)? = null

    override fun beginLoading(onStopped: () -> Unit) {
        releaseCurrent(notifyStopped = false)
        this.onStopped = onStopped
        CallRecordingPlaybackRegistry.activate(this)
    }

    override fun finishLoading() {
        releaseCurrent(notifyStopped = false)
        CallRecordingPlaybackRegistry.clear(this)
    }

    override fun play(
        source: CallRecordingPlaybackSource,
        onStarted: () -> Unit,
        onCompleted: () -> Unit,
        onFailed: () -> Unit,
        onPaused: () -> Unit,
        onStopped: () -> Unit,
    ) {
        CallRecordingPlaybackRegistry.activate(this)
        releaseCurrent(notifyStopped = false)
        this.onPaused = onPaused
        this.onStopped = onStopped
        val created = MediaPlayer()
        player = created
        try {
            created.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            created.setOnPreparedListener { prepared ->
                if (player === prepared) {
                    prepared.start()
                    onStarted()
                }
            }
            created.setOnCompletionListener { completed ->
                if (player === completed) {
                    CallRecordingPlaybackRegistry.clear(this)
                    onCompleted()
                }
            }
            created.setOnErrorListener { failed, _, _ ->
                if (player === failed) {
                    releaseCurrent(notifyStopped = false)
                    CallRecordingPlaybackRegistry.clear(this)
                    onFailed()
                }
                true
            }
            created.setDataSource(appContext, android.net.Uri.parse(source.url))
            created.prepareAsync()
        } catch (_: Throwable) {
            releaseCurrent(notifyStopped = false)
            CallRecordingPlaybackRegistry.clear(this)
            onFailed()
        }
    }

    override fun pause(): Boolean {
        val current = player ?: return false
        return runCatching {
            if (!current.isPlaying) return@runCatching false
            current.pause()
            true
        }.getOrDefault(false)
    }

    override fun resume(): Boolean {
        val current = player ?: return false
        return runCatching {
            current.start()
            CallRecordingPlaybackRegistry.activate(this)
            true
        }.getOrDefault(false)
    }

    override fun stop() {
        releaseCurrent(notifyStopped = false)
        CallRecordingPlaybackRegistry.clear(this)
    }

    override fun currentPositionMillis(): Long? = runCatching {
        player?.currentPosition?.toLong()
    }.getOrNull()

    override fun durationMillis(): Long? = runCatching {
        player?.duration?.toLong()?.takeIf { it > 0L }
    }.getOrNull()

    internal fun stopForReplacement() {
        stopFromOutside(reason = "replacement")
    }

    internal fun stopForHost(reason: String) {
        stopFromOutside(reason)
    }

    private fun stopFromOutside(reason: String) {
        val callback = onStopped
        val hadActivity = player != null || callback != null
        releaseCurrent(notifyStopped = false)
        if (!hadActivity) return
        AppFileLogger.i(
            Tag,
            "CALL_RECORDING playback_stopped callId=$callId reason=$reason",
        )
        callback?.invoke()
    }

    private fun releaseCurrent(notifyStopped: Boolean) {
        val current = player
        player = null
        runCatching { current?.stop() }
        current?.reset()
        current?.release()
        if (notifyStopped) onStopped?.invoke()
        onPaused = null
        onStopped = null
    }

    private companion object {
        const val Tag = "CallRecordingPlayer"
    }
}

internal object CallRecordingPlaybackControl {
    private val playbackRequestVersion = AtomicLong(0L)

    fun capturePlaybackRequestVersion(): Long = playbackRequestVersion.get()

    fun isPlaybackRequestCurrent(version: Long): Boolean =
        playbackRequestVersion.get() == version

    fun beginPlaybackRequest(): Long = playbackRequestVersion.incrementAndGet()

    fun stopActiveForVoiceInput() {
        playbackRequestVersion.incrementAndGet()
        CallRecordingPlaybackRegistry.stopActiveForHost("voice_input")
    }

    fun stopActiveForHost(reason: String) {
        playbackRequestVersion.incrementAndGet()
        CallRecordingPlaybackRegistry.stopActiveForHost(reason)
    }
}

private object CallRecordingPlaybackRegistry {
    private var activePlayer: WeakReference<CallRecordingPlayer>? = null

    @Synchronized
    fun activate(player: CallRecordingPlayer) {
        val previous = activePlayer?.get()
        if (previous !== player) previous?.stopForReplacement()
        activePlayer = WeakReference(player)
    }

    @Synchronized
    fun stopActiveForHost(reason: String) {
        val current = activePlayer?.get()
        activePlayer = null
        current?.stopForHost(reason)
    }

    @Synchronized
    fun clear(player: CallRecordingPlayer) {
        if (activePlayer?.get() === player) activePlayer = null
    }
}
