package com.vvtech.aiassistant.features.assistant.speech

import com.vvtech.aiassistant.logging.AppFileLogger

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class AudioRecorder(
    private val sampleRate: Int = SAMPLE_RATE_HZ,
    private val channelConfig: Int = AudioFormat.CHANNEL_IN_MONO,
    private val encoding: Int = AudioFormat.ENCODING_PCM_16BIT
) {

    companion object {
        private const val TAG = "AudioRecorder"
        private const val SAMPLE_RATE_HZ = 16_000
        private const val BITS_PER_SAMPLE = 16
        private const val CHANNELS = 1
        private const val CHUNK_DURATION_MS = 200
        private val CHUNK_SIZE_BYTES =
            SAMPLE_RATE_HZ * BITS_PER_SAMPLE / 8 * CHANNELS * CHUNK_DURATION_MS / 1000
    }

    private val recording = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var workerThread: Thread? = null

    fun start(onPcmChunk: (ByteArray) -> Unit) {
        if (recording.get()) {
            AppFileLogger.w(TAG, "start() called while already recording, ignoring")
            return
        }
        val minBuffer = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
        if (minBuffer <= 0) {
            throw IllegalStateException("AudioRecord.getMinBufferSize returned $minBuffer -- check RECORD_AUDIO permission and audio config")
        }
        val bufferSize = maxOf(minBuffer, CHUNK_SIZE_BYTES * 4)
        val recorder = runCatching {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                encoding,
                bufferSize
            )
        }.getOrElse { throwable ->
            throw IllegalStateException("Failed to create AudioRecord: ${throwable.message}", throwable)
        }
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            throw IllegalStateException("AudioRecord not initialized -- RECORD_AUDIO permission may be missing")
        }
        runCatching { recorder.startRecording() }.onFailure { throwable ->
            runCatching { recorder.release() }
            throw IllegalStateException("AudioRecord.startRecording failed: ${throwable.message}", throwable)
        }
        if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            runCatching {
                recorder.stop()
                recorder.release()
            }
            throw IllegalStateException("AudioRecord did not enter RECORDING state")
        }
        audioRecord = recorder
        recording.set(true)
        AppFileLogger.i(TAG, "recording started sampleRate=$sampleRate bufferSize=$bufferSize chunkSize=$CHUNK_SIZE_BYTES")

        workerThread = thread(start = true, name = "AudioRecorder-capture") {
            val buffer = ByteArray(CHUNK_SIZE_BYTES)
            try {
                while (recording.get()) {
                    val count = readAudio(recorder, buffer)
                    if (count > 0) {
                        val chunk = if (count == buffer.size) buffer.copyOf() else buffer.copyOfRange(0, count)
                        onPcmChunk(chunk)
                    } else if (count < 0) {
                        AppFileLogger.w(TAG, "AudioRecord.read returned error code=$count")
                        break
                    }
                }
            } catch (throwable: Throwable) {
                AppFileLogger.e(TAG, "capture loop error", throwable)
            } finally {
                releaseRecorder(recorder)
                AppFileLogger.i(TAG, "capture loop exited")
            }
        }
    }

    fun stop() {
        if (!recording.compareAndSet(true, false)) {
            return
        }
        AppFileLogger.i(TAG, "stop() called, waiting for capture thread")
        workerThread?.join(2_000L)
        workerThread = null
        audioRecord = null
    }

    fun isRecording(): Boolean = recording.get()

    private fun readAudio(record: AudioRecord, buffer: ByteArray): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
        } else {
            record.read(buffer, 0, buffer.size)
        }
    }

    private fun releaseRecorder(recorder: AudioRecord) {
        runCatching {
            recorder.stop()
        }
        runCatching {
            recorder.release()
        }
    }
}
