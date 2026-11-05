package com.vvtech.phone_agent

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min

/** The same MediaPlayer owns playback and its Visualizer; no microphone capture. */
class CallRecordingPlayerChannel(messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "phone_agent/call_recording_player")
    private val events = EventChannel(messenger, "phone_agent/call_recording_player/events")
    private val handler = Handler(Looper.getMainLooper())
    private val players = mutableMapOf<String, Session>()
    private var sink: EventChannel.EventSink? = null

    init { methods.setMethodCallHandler(this); events.setStreamHandler(this) }
    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("playerId") ?: return result.error("invalid", "Missing player", null)
        val generation = call.argument<Number>("generation")?.toInt() ?: 0
        try {
            when (call.method) {
                "prepare" -> {
                    players.remove(id)?.release()
                    val source = call.argument<String>("source") ?: throw IllegalArgumentException()
                    val session = Session(id, generation)
                    players[id] = session
                    session.prepare(source, result)
                }
                "stop" -> { players.remove(id)?.release(); result.success(null) }
                "play", "resume", "pause" -> {
                    val session = players[id]?.takeIf { it.generation == generation }
                        ?: throw IllegalStateException()
                    when (call.method) {
                        "play" -> session.start(rewind = true)
                        "resume" -> session.start(rewind = false)
                        "pause" -> session.pause()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("playback", "Recording playback unavailable", null) }
    }

    private inner class Session(val id: String, val generation: Int) {
        private val player = MediaPlayer()
        private var visualizer: Visualizer? = null
        private var pending: MethodChannel.Result? = null
        private var released = false
        private var playing = false
        private val timeout = Runnable {
            pending?.error("prepare", "Recording preparation timed out", null)
            pending = null
            release()
        }
        private val position = object : Runnable {
            override fun run() {
                if (!playing || !current()) return
                runCatching { emit("position", mapOf("positionMillis" to player.currentPosition)) }
                handler.postDelayed(this, 200)
            }
        }
        private fun current() = !released && players[id] === this
        private fun emit(type: String, values: Map<String, Any?> = emptyMap()) {
            if (current()) sink?.success(mapOf(
                "playerId" to id, "generation" to generation, "type" to type,
            ) + values)
        }
        fun prepare(source: String, result: MethodChannel.Result) {
            pending = result
            player.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            player.setOnPreparedListener {
                if (!current()) return@setOnPreparedListener
                handler.removeCallbacks(timeout)
                pending?.success(player.duration)
                pending = null
            }
            player.setOnCompletionListener {
                if (current()) { stopMeter(); emit("completed") }
            }
            player.setOnErrorListener { _, _, _ ->
                if (current()) {
                    pending?.error("prepare", "Recording unavailable", null)
                    pending = null
                    emit("failed")
                    release()
                }
                true
            }
            try {
                player.setDataSource(source)
                player.prepareAsync()
                handler.postDelayed(timeout, 30_000)
            } catch (_: Exception) {
                pending = null
                release()
                result.error("prepare", "Recording unavailable", null)
            }
        }
        fun start(rewind: Boolean) {
            if (rewind) player.seekTo(0)
            player.start()
            playing = true
            startMeter()
            handler.removeCallbacks(position)
            handler.post(position)
        }
        fun pause() {
            if (playing) player.pause()
            stopMeter()
            emit("paused")
        }
        private fun startMeter() {
            stopVisualizer()
            // Visualizer failure must never affect media playback.
            runCatching {
                val meter = Visualizer(player.audioSessionId)
                visualizer = meter
                val range = Visualizer.getCaptureSizeRange()
                meter.captureSize = 256.coerceIn(range[0], range[1])
                runCatching { meter.measurementMode = Visualizer.MEASUREMENT_MODE_PEAK_RMS }
                meter.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray?, rate: Int) {
                        if (waveform == null) return
                        val bytes = waveform.map { it.toInt() and 0xff }
                        val measurement = Visualizer.MeasurementPeakRms()
                        val rms = runCatching {
                            if (v?.getMeasurementPeakRms(measurement) == Visualizer.SUCCESS)
                                measurement.mRms else null
                        }.getOrNull()
                        handler.post { if (playing) emit("waveform", mapOf("bytes" to bytes, "rms" to rms)) }
                    }
                    override fun onFftDataCapture(v: Visualizer?, fft: ByteArray?, rate: Int) = Unit
                }, min(Visualizer.getMaxCaptureRate(), 15_000), true, false)
                meter.enabled = true
            }.onFailure {
                stopVisualizer()
                emit("waveform", mapOf("bytes" to emptyList<Int>()))
            }
        }
        private fun stopVisualizer() {
            runCatching { visualizer?.enabled = false }
            runCatching { visualizer?.release() }
            visualizer = null
        }
        private fun stopMeter() {
            playing = false
            handler.removeCallbacks(position)
            stopVisualizer()
        }
        fun release() {
            if (released) return
            pending?.error("cancelled", "Recording preparation cancelled", null)
            pending = null
            released = true
            handler.removeCallbacks(timeout)
            stopMeter()
            runCatching { player.release() }
        }
    }
    fun setForeground(value: Boolean) {
        if (!value) players.values.toList().forEach { runCatching { it.pause() } }
    }
    fun close() {
        players.values.toList().forEach { it.release() }
        players.clear()
        sink = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
