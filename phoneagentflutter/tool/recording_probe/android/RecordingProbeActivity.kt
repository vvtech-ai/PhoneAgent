package com.vvtech.phone_agent

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.sqrt

/** Isolated app: only the production encoder and a synthetic decoder inspector. */
class RecordingProbeActivity : FlutterActivity() {
    private var encoder: DomesticRecordingChannel? = null
    private val worker = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        encoder = DomesticRecordingChannel(this, messenger)
        MethodChannel(messenger, "phone_agent/synthetic_recording_inspector").setMethodCallHandler { call, result ->
            val path = call.argument<String>("m4aPath")
            if (call.method != "inspect" || path == null) result.notImplemented()
            else worker.execute {
                val metrics = runCatching { inspect(File(path)) }
                Handler(Looper.getMainLooper()).post {
                    metrics.fold({ result.success(it) }, { result.error("synthetic_inspection_failed", "Synthetic AAC inspection failed", null) })
                }
            }
        }
    }
    private fun inspect(input: File): Map<String, Any> {
        val root = File(noBackupFilesDir, "domestic-recordings").canonicalFile
        check(input.canonicalPath.startsWith(root.path + "/") && input.name == "recording.m4a" && input.length() in 1..10000000)
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var frames = 0L
        var silentEnergy = 0.0; var silentCount = 0L
        var toneEnergy = 0.0; var toneCount = 0L
        try {
            extractor.setDataSource(input.path)
            check(extractor.trackCount == 1)
            val format = extractor.getTrackFormat(0)
            val mime = checkNotNull(format.getString(MediaFormat.KEY_MIME))
            check(mime == MediaFormat.MIMETYPE_AUDIO_AAC && format.getInteger(MediaFormat.KEY_SAMPLE_RATE) == 16000 && format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) == 1)
            val duration = format.getLong(MediaFormat.KEY_DURATION) / 1000000.0
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            extractor.selectTrack(0)
            val codec = MediaCodec.createDecoderByType(mime)
            decoder = codec
            codec.configure(format, null, null, 0)
            codec.start()
            val info = MediaCodec.BufferInfo()
            var inputEnded = false; var outputEnded = false
            val deadline = SystemClock.elapsedRealtime() + 10000
            while (!outputEnded) {
                check(SystemClock.elapsedRealtime() < deadline && frames < 100000)
                if (!inputEnded) {
                    val index = codec.dequeueInputBuffer(10000)
                    if (index >= 0) {
                        val buffer = checkNotNull(codec.getInputBuffer(index))
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputEnded = true
                        } else {
                            codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                when (val index = codec.dequeueOutputBuffer(info, 10000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val output = codec.outputFormat
                        check(output.getInteger(MediaFormat.KEY_SAMPLE_RATE) == 16000 && output.getInteger(MediaFormat.KEY_CHANNEL_COUNT) == 1)
                        if (output.containsKey(MediaFormat.KEY_PCM_ENCODING)) check(output.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_16BIT)
                    }
                    else -> if (index >= 0) {
                        val buffer = checkNotNull(codec.getOutputBuffer(index)).order(ByteOrder.LITTLE_ENDIAN)
                        buffer.position(info.offset); buffer.limit(info.offset + info.size)
                        check(info.size % 2 == 0)
                        while (buffer.remaining() >= 2) {
                            val value = buffer.short / 32768.0
                            if (frames < 9600) { silentEnergy += value * value; silentCount++ }
                            if (frames >= 24000) { toneEnergy += value * value; toneCount++ }
                            frames++
                        }
                        outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        codec.releaseOutputBuffer(index, false)
                    }
                }
            }
            check(silentCount > 0 && toneCount > 0)
            return mapOf("codec" to mime, "sampleRate" to 16000, "channels" to 1,
                "durationSeconds" to duration, "decodedFrames" to frames,
                "silenceRms" to sqrt(silentEnergy / silentCount), "toneRms" to sqrt(toneEnergy / toneCount))
        } finally {
            runCatching { decoder?.stop() }; runCatching { decoder?.release() }; extractor.release()
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        encoder?.close(); encoder = null; worker.shutdown()
    }
}
