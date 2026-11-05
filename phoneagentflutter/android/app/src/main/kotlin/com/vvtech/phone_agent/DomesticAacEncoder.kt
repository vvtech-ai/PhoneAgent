package com.vvtech.phone_agent

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.SystemClock
import java.io.File
import java.io.FileInputStream

/** File-streamed 16k mono PCM16LE; no microphone ownership or network access. */
internal object DomesticAacEncoder {
    fun encode(input: File, output: File, cancelled: () -> Boolean) {
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var started = false
        val part = File(output.parentFile, "recording.encoding.m4a")
        check(!part.exists() && !output.exists())
        try {
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, 16000, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 48000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            val activeCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            codec = activeCodec
            activeCodec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            activeCodec.start()
            val activeMuxer = MediaMuxer(part.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = activeMuxer
            val info = MediaCodec.BufferInfo()
            var queuedFrames = 0L
            var inputEnded = false
            var outputEnded = false
            var track = -1
            var progressAt = SystemClock.elapsedRealtime()
            val chunk = ByteArray(16384)
            FileInputStream(input).use { source ->
                while (!outputEnded) {
                    check(!cancelled() && SystemClock.elapsedRealtime() - progressAt < 15000)
                    if (!inputEnded) {
                        val index = activeCodec.dequeueInputBuffer(10000)
                        if (index >= 0) {
                            val buffer = checkNotNull(activeCodec.getInputBuffer(index)).apply { clear() }
                            val capacity = minOf(buffer.remaining(), chunk.size) / 2 * 2
                            check(capacity > 0)
                            val read = source.read(chunk, 0, capacity)
                            val pts = queuedFrames * 1000000L / 16000
                            if (read < 0) {
                                activeCodec.queueInputBuffer(index, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputEnded = true
                            } else {
                                check(read > 0 && read % 2 == 0)
                                buffer.put(chunk, 0, read)
                                activeCodec.queueInputBuffer(index, 0, read, pts, 0)
                                queuedFrames += read / 2
                            }
                            progressAt = SystemClock.elapsedRealtime()
                        }
                    }
                    when (val index = activeCodec.dequeueOutputBuffer(info, 10000)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            check(!started)
                            track = activeMuxer.addTrack(activeCodec.outputFormat)
                            activeMuxer.start()
                            started = true
                            progressAt = SystemClock.elapsedRealtime()
                        }
                        else -> if (index >= 0) {
                            val buffer = checkNotNull(activeCodec.getOutputBuffer(index))
                            if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                check(started && track >= 0)
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                activeMuxer.writeSampleData(track, buffer, info)
                                check(part.length() <= 300L * 1024 * 1024)
                            }
                            outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            activeCodec.releaseOutputBuffer(index, false)
                            progressAt = SystemClock.elapsedRealtime()
                        }
                    }
                }
            }
            check(started && !cancelled())
            activeMuxer.stop()
            started = false
            activeMuxer.release()
            muxer = null
            activeCodec.stop()
            activeCodec.release()
            codec = null
            check(part.length() > 0 && part.renameTo(output))
        } finally {
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            part.delete()
        }
    }
}
