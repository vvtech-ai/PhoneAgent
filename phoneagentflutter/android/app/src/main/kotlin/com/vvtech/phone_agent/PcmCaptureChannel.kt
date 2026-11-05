package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioManager
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** PCM hardware only. No sockets, permissions prompts, transcripts or files. */
class PcmCaptureChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/pcm_capture")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var current: Capture? = null // Main-thread ownership.
    private var foreground = true
    private var closed = false

    private class Capture(val id: String, val duplex: Boolean, val speechInput: Boolean, val callAudioId: String?) {
        val running = AtomicBoolean(true)
        var reading = false // Main thread.
        var record: AudioRecord? = null // Worker only.
        var echo: AcousticEchoCanceler? = null
        var noise: NoiseSuppressor? = null
        var route: PcmCommunicationRoute? = null
    }

    private val onCallAudioLost: () -> Unit = {
        current?.let { if (it.callAudioId != null && !TranslationCallAudioOwner.matches(it.callAudioId)) stop(it) }
    }
    init { channel.setMethodCallHandler(::handle); TranslationCallAudioOwner.lost.add(onCallAudioLost) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("captureId")
        if (closed || id.isNullOrBlank() || id.length > 128) {
            result.error("capture_failed", "Capture unavailable", null)
            return
        }
        when (call.method) {
            "start" -> start(id, call.argument<Boolean>("duplex") == true,
                call.argument<Boolean>("speechInput") == true, call.argument<String>("callAudioId"), result)
            "speaker" -> {
                val capture = current
                if (capture == null || capture.id != id || !capture.running.get() || !capture.duplex) {
                    result.error("capture_interrupted", "Capture unavailable", null)
                } else worker.execute {
                    val ok = runCatching {
                        check(capture.running.get())
                        requireNotNull(capture.route).select(if (call.argument<Boolean>("enabled") == true) "speaker" else "earpiece")
                    }.isSuccess
                    main.post {
                        if (ok) result.success(true)
                        else result.error("capture_route_failed", "Route unavailable", null)
                    }
                }
            }
            "read" -> read(id, result)
            "stop" -> {
                val capture = current
                if (capture == null || capture.id != id) result.success(true)
                else stop(capture, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(id: String, duplex: Boolean, speechInput: Boolean,
                      callAudioId: String?, result: MethodChannel.Result) {
        if (current != null) {
            result.error("capture_busy", "Capture active", null); return
        }
        if ((callAudioId != null && (!duplex || !TranslationCallAudioOwner.matches(callAudioId))) ||
            (!foreground && !TranslationCallAudioOwner.matches(callAudioId))) {
            result.error("capture_interrupted", "Capture not in foreground", null); return
        }
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("permission_denied", "Microphone permission required", null); return
        }
        val capture = Capture(id, duplex, speechInput, callAudioId)
        current = capture
        worker.execute {
            val started = runCatching { open(capture) }.getOrDefault(false)
            main.post {
                if (started && capture.running.get() && current === capture) result.success(true)
                else result.error("capture_failed", "Capture could not start", null)
            }
        }
    }

    @Suppress("MissingPermission")
    private fun open(capture: Capture): Boolean {
        val min = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (min <= 0) return false
        if (capture.duplex) {
            capture.route = PcmCommunicationRoute(activity.getSystemService(Activity.AUDIO_SERVICE) as AudioManager)
            capture.route?.start()
        }
        val sources = when {
            capture.duplex -> listOf(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            capture.speechInput -> listOf(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                MediaRecorder.AudioSource.MIC,
            )
            else -> listOf(MediaRecorder.AudioSource.VOICE_RECOGNITION, MediaRecorder.AudioSource.MIC)
        }
        for (source in sources) {
            if (!capture.running.get()) return false
            val record = runCatching {
                AudioRecord(source, 16000, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, maxOf(min, 640 * 4))
            }.getOrNull() ?: continue
            capture.record = record
            val started = runCatching {
                check(record.state == AudioRecord.STATE_INITIALIZED)
                if (AcousticEchoCanceler.isAvailable()) {
                    capture.echo = runCatching {
                        AcousticEchoCanceler.create(record.audioSessionId)?.apply { enabled = true }
                    }.getOrNull()
                }
                if (NoiseSuppressor.isAvailable()) {
                    capture.noise = runCatching {
                        NoiseSuppressor.create(record.audioSessionId)?.apply { enabled = true }
                    }.getOrNull()
                }
                // v65 intentionally does not enable AGC (noise amplification).
                if (!capture.running.get()) return@runCatching false
                record.startRecording()
                record.recordingState == AudioRecord.RECORDSTATE_RECORDING
            }.getOrDefault(false)
            if (started) return true
            if (!release(capture)) return false
        }
        return false
    }

    private fun read(id: String, result: MethodChannel.Result) {
        val capture = current
        if (capture == null || capture.id != id || !capture.running.get()) {
            result.success(null); return
        }
        if (capture.reading) {
            result.error("capture_busy", "Read already pending", null); return
        }
        capture.reading = true
        worker.execute {
            val bytes = ByteArray(640)
            var count = 0
            val deadline = SystemClock.elapsedRealtime() + 5000
            while (capture.running.get() && count == 0 && SystemClock.elapsedRealtime() < deadline) {
                count = runCatching {
                    capture.record?.read(bytes, 0, bytes.size, AudioRecord.READ_NON_BLOCKING) ?: -1
                }.getOrDefault(-1)
                if (count == 0) Thread.sleep(10)
            }
            main.post {
                capture.reading = false
                if (current !== capture || !capture.running.get()) result.success(null)
                else if (count <= 0 || count % 2 != 0) {
                    capture.running.set(false)
                    result.error("capture_read_failed", "Microphone read failed", null)
                } else result.success(bytes.copyOf(count))
            }
        }
    }

    private fun stop(capture: Capture, result: MethodChannel.Result? = null) {
        capture.running.set(false)
        // The non-blocking read exits first; no concurrent read/release race.
        worker.execute {
            val released = release(capture)
            main.post {
                if (released && current === capture) current = null
                if (released) result?.success(true)
                else result?.error("capture_stop_failed", "Microphone release failed", null)
            }
        }
    }

    private fun release(capture: Capture): Boolean {
        runCatching { capture.echo?.release() }; capture.echo = null
        runCatching { capture.noise?.release() }; capture.noise = null
        val record = capture.record
        runCatching { record?.stop() }
        if (runCatching { record?.release() }.isFailure) return false
        capture.record = null
        if (runCatching { capture.route?.stop() }.isFailure) return false
        capture.route = null
        return true
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (!value) current?.let { if (!TranslationCallAudioOwner.matches(it.callAudioId)) stop(it) }
    }

    fun close() {
        if (closed) return
        closed = true
        TranslationCallAudioOwner.lost.remove(onCallAudioLost)
        channel.setMethodCallHandler(null)
        current?.let { stop(it) }
        worker.shutdown() // Queued release still executes.
    }
}
