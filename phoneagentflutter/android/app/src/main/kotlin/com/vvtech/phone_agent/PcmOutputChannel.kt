package com.vvtech.phone_agent

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioTrack
import android.media.AudioFormat
import android.os.Build
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** PCM only. Business lifecycle, synthesis and ownership stay in Dart. */
class PcmOutputChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/pcm_output")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadScheduledExecutor()
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    @Volatile private var closed = false
    @Volatile private var foreground = true
    private var lastFailure: String? = null
    private var current: Output? = null // Worker thread only.

    private val onCallAudioLost: () -> Unit = {
        if (!closed) worker.execute {
            current?.let { if (it.callAudioId != null && !TranslationCallAudioOwner.matches(it.callAudioId)) release(it) }
        }
    }
    init {
        TranslationCallAudioOwner.lost.add(onCallAudioLost)
        channel.setMethodCallHandler { call, result ->
            val id = call.argument<String>("outputId")
            if (id.isNullOrBlank() || id.length > 128) {
                error(result, "output_invalid")
            } else if (closed) {
                error(result, "output_interrupted")
            } else {
                worker.execute {
                    when (call.method) {
                        "start" -> start(id, call.argument<Int>("sampleRate") ?: 0,
                            call.argument<Boolean>("communication") == true, call.argument<String>("callAudioId"),
                            call.argument<Boolean>("queuedTranslation") == true, result)
                        "play" -> play(id, call.argument<ByteArray>("bytes"), result)
                        "enqueue" -> play(id, call.argument<ByteArray>("bytes"), result, enqueue = true)
                        "drain" -> drain(id, result)
                        "statistics" -> statistics(id, result)
                        "enabled" -> enabled(id, call.argument<Boolean>("enabled") == true, result)
                        "route" -> route(id, call.argument<String>("select"), result)
                        "stop" -> {
                            val output = current
                            if (output == null || output.id != id) success(result)
                            else if (release(output)) success(result)
                            else error(result, "output_stop_failed")
                        }
                        else -> main.post { result.notImplemented() }
                    }
                }
            }
        }
    }

    private fun start(id: String, rate: Int, communication: Boolean, callAudioId: String?, queuedTranslation: Boolean, result: MethodChannel.Result) {
        if (closed || (callAudioId != null && (!communication || !TranslationCallAudioOwner.matches(callAudioId))) ||
            (!foreground && !TranslationCallAudioOwner.matches(callAudioId))) return error(result, "output_interrupted")
        if (queuedTranslation && !communication) return error(result, "output_invalid")
        if (current != null) return error(result, "output_busy")
        if (rate !in 8000..48000) return error(result, "output_invalid")
        lastFailure = null
        var output: Output? = null
        try {
            val attributes = AudioAttributes.Builder()
                .setUsage(if (communication) AudioAttributes.USAGE_VOICE_COMMUNICATION else AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .apply {
                    if (android.os.Build.VERSION.SDK_INT >= 29) {
                        setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_SYSTEM)
                    }
                }.build()
            val minimum = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT)
            check(minimum > 0)
            val track = AudioTrack.Builder().setAudioAttributes(attributes)
                .setAudioFormat(AudioFormat.Builder().setSampleRate(rate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(maxOf(minimum, if (queuedTranslation) 2560 else rate / 5 * 2)).build()
            if (queuedTranslation && Build.VERSION.SDK_INT >= 31) {
                track.setStartThresholdInFrames(maxOf(1, rate / 50))
            }
            output = Output(id, rate, track, callAudioId, queuedTranslation)
            if (queuedTranslation) Log.i("TranslationPcm", "stage=start bufferFrames=${track.bufferSizeInFrames} thresholdFrames=${if (Build.VERSION.SDK_INT >= 31) track.startThresholdInFrames else -1}")
            current = output
            output.diagnosis = !communication
            if (communication) {
                output.route = PcmCommunicationRoute(manager)
                output.route?.start()
            }
            check(track.state == AudioTrack.STATE_INITIALIZED)
            val owned = output
            val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener({ change ->
                    if (change < 0 && !closed) {
                        worker.execute {
                            if (current === owned) release(owned, "output_focus_lost")
                            if (TranslationCallAudioOwner.matches(owned.callAudioId)) TranslationCallAudioOwner.stopNow?.invoke()
                        }
                    }
                }, main).build()
            output.focus = focus
            check(manager.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
            track.play()
            if (output.diagnosis) PcmOutputDiagnostics.record(track, manager, "start")
            success(result)
        } catch (_: Exception) {
            output?.let { release(it) }
            error(result, "output_start_failed")
        }
    }

    private fun play(id: String, bytes: ByteArray?, result: MethodChannel.Result, enqueue: Boolean = false) {
        val output = current
        if (output == null || output.id != id || output.stopped || !output.enabled || (!foreground && !TranslationCallAudioOwner.matches(output.callAudioId))) {
            return error(result, lastFailure ?: "output_interrupted")
        }
        if (enqueue && !output.queuedTranslation) return error(result, "output_invalid")
        output.failure?.let { return error(result, it) }
        if (bytes == null || bytes.isEmpty() || bytes.size % 2 != 0 ||
            output.pendingBytes + bytes.size > output.rate * 4) {
            return error(result, "output_capacity")
        }
        val now = SystemClock.elapsedRealtime()
        if (output.lastEnqueueMs != 0L) output.maxEnqueueGapMs = maxOf(output.maxEnqueueGapMs, now - output.lastEnqueueMs)
        output.lastEnqueueMs = now
        output.enqueuedBuffers++
        output.pendingBytes += bytes.size
        output.maxQueuedBytes = maxOf(output.maxQueuedBytes, output.pendingBytes)
        output.queue.add(Chunk(bytes, result, enqueue))
        if (!output.pumping) {
            output.lastProgress = SystemClock.elapsedRealtime()
            output.pumping = true
            pump(output)
        }
    }

    private fun statistics(id: String, result: MethodChannel.Result) {
        val output = current
        if (output == null || output.id != id || output.stopped) return error(result, "output_interrupted")
        val stats = mapOf("outputPlatform" to 1,
            "outputQueuedMs" to output.pendingBytes * 500 / output.rate,
            "outputMaxQueuedMs" to output.maxQueuedBytes * 500 / output.rate,
            "outputEmptyTransitions" to output.emptyTransitions,
            "outputMaxEnqueueGapMs" to output.maxEnqueueGapMs,
            "outputEnqueuedBuffers" to output.enqueuedBuffers,
            "outputPlayedBuffers" to output.playedBuffers,
            "outputHardwareUnderruns" to output.track.underrunCount)
        main.post { result.success(stats) }
    }

    private fun drain(id: String, result: MethodChannel.Result) {
        val output = current
        if (output == null || output.id != id || !output.queuedTranslation || output.stopped) {
            return error(result, lastFailure ?: "output_interrupted")
        }
        output.failure?.let { return error(result, it) }
        // Tail padding lets very short streams cross pre-31 hardware thresholds.
        // Its callback is tied to the actual head, so all prior samples drained.
        play(id, ByteArray(output.track.bufferSizeInFrames * 2), result)
    }

    private fun pump(output: Output) {
        if (current !== output || output.stopped) return
        if (closed || (!foreground && !TranslationCallAudioOwner.matches(output.callAudioId))) { release(output); return }
        try {
            while (output.queue.isNotEmpty()) {
                val chunk = output.queue.first
                val count = output.track.write(chunk.bytes, chunk.offset,
                    chunk.bytes.size - chunk.offset, AudioTrack.WRITE_NON_BLOCKING)
                check(count >= 0 && count % 2 == 0)
                if (count == 0) break
                if (!output.firstWrite && count > 0) {
                    output.firstWrite = true
                    if (output.queuedTranslation) Log.i("TranslationPcm", "stage=firstWrite")
                }
                chunk.offset += count
                output.writtenFrames += count / 2
                if (chunk.offset == chunk.bytes.size) {
                    chunk.endFrame = output.writtenFrames
                    output.queue.removeFirst()
                    if (chunk.ackOnWrite) {
                        chunk.result?.let { success(it) }
                        chunk.result = null
                    }
                    output.playing.add(chunk)
                }
            }
            val head = output.track.playbackHeadPosition.toLong() and 0xffffffffL
            if (head < output.lastHead) output.wrapFrames += 1L shl 32
            val played = output.wrapFrames + head
            if (head != output.lastHead) output.lastProgress = SystemClock.elapsedRealtime()
            output.lastHead = head
            if (!output.firstPlayed && played > 0) {
                output.firstPlayed = true
                if (output.diagnosis) PcmOutputDiagnostics.record(output.track, manager, "first_played", played)
                if (output.queuedTranslation) Log.i("TranslationPcm", "stage=firstPlayed")
            }
            while (output.playing.isNotEmpty() && output.playing.first.endFrame <= played) {
                val chunk = output.playing.removeFirst()
                output.pendingBytes -= chunk.bytes.size
                output.playedBuffers++
                chunk.result?.let { success(it) } // Ordinary play/drain keep actual completion.
            }
            if (output.pendingBytes == 0) {
                if (output.diagnosis && !output.emptyLogged) {
                    output.emptyLogged = true
                    PcmOutputDiagnostics.record(output.track, manager, "queue_empty", played)
                }
                output.emptyTransitions++
                output.pumping = false
                return
            }
            if (SystemClock.elapsedRealtime() - output.lastProgress >= 5000) {
                release(output, "output_stalled")
                return
            }
            val generation = output.generation
            worker.schedule({ if (generation == output.generation) pump(output) }, 10, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            release(output, "output_play_failed")
        }
    }

    private fun enabled(id: String, enabled: Boolean, result: MethodChannel.Result) {
        val output = current
        if (output == null || output.id != id || output.stopped || output.route == null) {
            return error(result, "output_interrupted")
        }
        try {
            output.enabled = false
            output.generation++
            output.track.pause()
            output.track.flush()
            while (output.queue.isNotEmpty()) output.queue.removeFirst().result?.let { error(it, "output_interrupted") }
            while (output.playing.isNotEmpty()) output.playing.removeFirst().result?.let { error(it, "output_interrupted") }
            output.pendingBytes = 0
            output.writtenFrames = 0
            output.lastHead = 0
            output.wrapFrames = 0
            output.pumping = false
            if (enabled) output.track.play()
            output.enabled = enabled
            success(result)
        } catch (_: Exception) { error(result, "output_play_failed") }
    }

    private fun route(id: String, select: String?, result: MethodChannel.Result) {
        val output = current
        if (output == null || output.id != id || output.stopped || output.route == null) {
            return error(result, "output_interrupted")
        }
        try {
            if (select != null) output.route!!.select(select)
            val snapshot = output.route!!.snapshot()
            main.post { result.success(snapshot) }
        } catch (_: Exception) { error(result, "output_route_failed") }
    }

    private fun release(output: Output, reason: String = "output_cancelled"): Boolean {
        val failure = if (output.queuedTranslation) reason else "output_interrupted"
        lastFailure = failure
        output.failure = failure
        if (output.queuedTranslation) Log.i("TranslationPcm", "stage=release reason=$reason")
        output.stopped = true
        while (output.queue.isNotEmpty()) output.queue.removeFirst().result?.let { error(it, failure) }
        while (output.playing.isNotEmpty()) output.playing.removeFirst().result?.let { error(it, failure) }
        output.pendingBytes = 0
        return try {
            if (!output.released) {
                runCatching { output.track.pause() }
                runCatching { output.track.flush() }
                output.track.release()
                output.released = true
            }
            output.focus?.let { manager.abandonAudioFocusRequest(it) }
            output.focus = null
            output.route?.stop()
            if (current === output) current = null
            true
        } catch (_: Exception) { false }
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (!value && !closed) worker.execute { current?.let { if (!TranslationCallAudioOwner.matches(it.callAudioId)) release(it) } }
    }

    fun close() {
        TranslationCallAudioOwner.lost.remove(onCallAudioLost)
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        worker.execute {
            current?.let { release(it) }
            worker.shutdown()
        }
    }

    private fun success(result: MethodChannel.Result) { main.post { result.success(true) } }
    private fun error(result: MethodChannel.Result, code: String) {
        main.post { result.error(code, "PCM output unavailable", null) }
    }

    private class Chunk(val bytes: ByteArray, var result: MethodChannel.Result?, val ackOnWrite: Boolean = false) {
        var offset = 0
        var endFrame = 0L
    }
    private class Output(val id: String, val rate: Int, val track: AudioTrack, val callAudioId: String?, val queuedTranslation: Boolean) {
        var failure: String? = null
        var diagnosis = false
        var emptyLogged = false
        var firstWrite = false
        var firstPlayed = false
        var focus: AudioFocusRequest? = null
        val queue = ArrayDeque<Chunk>()
        val playing = ArrayDeque<Chunk>()
        var maxQueuedBytes = 0
        var maxEnqueueGapMs = 0L
        var lastEnqueueMs = 0L
        var enqueuedBuffers = 0
        var playedBuffers = 0
        var emptyTransitions = 0
        var pendingBytes = 0
        var writtenFrames = 0L
        var lastHead = 0L
        var wrapFrames = 0L
        var lastProgress = SystemClock.elapsedRealtime()
        var pumping = false
        var stopped = false
        var released = false
        var enabled = true
        var generation = 0
        var route: PcmCommunicationRoute? = null
    }
}
