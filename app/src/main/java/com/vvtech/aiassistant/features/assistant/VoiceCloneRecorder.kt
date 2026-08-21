package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import kotlin.concurrent.thread
import kotlin.math.max

class VoiceCloneRecorder(context: Context) {

    companion object {
        private const val SampleRateHz = 24_000
        private const val ChannelCount = 1
        private const val BitsPerSample = 16
        private const val WavHeaderBytes = 44
    }

    data class RecordingResult(
        val file: File,
        val durationMs: Long,
        val audioBytes: Long
    )

    private val appContext = context.applicationContext

    @Volatile
    private var recording = false

    private var audioRecord: AudioRecord? = null
    private var workerThread: Thread? = null
    private var outputFile: File? = null
    private var audioBytesWritten: Long = 0L
    private var startElapsedRealtime: Long = 0L
    private var failure: Throwable? = null

    fun start(scriptId: String) {
        if (recording) {
            throw IllegalStateException(currentAppText(
                "当前已有录音任务，请先结束后再开始",
                "A recording is already in progress. Finish it before starting again."
            ))
        }
        val minBuffer = AudioRecord.getMinBufferSize(
            SampleRateHz,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            throw IllegalStateException(currentAppText(
                "录音初始化失败，请稍后再试",
                "Recording initialization failed. Please try again later."
            ))
        }
        val bufferSize = max(minBuffer, SampleRateHz)
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SampleRateHz,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            throw IllegalStateException(currentAppText(
                "麦克风初始化失败，请检查权限后重试",
                "Microphone initialization failed. Check permissions and try again."
            ))
        }

        val wavFile = File(
            appContext.cacheDir,
            "voice-clone-$scriptId-${System.currentTimeMillis()}.wav"
        )
        audioRecord = recorder
        outputFile = wavFile
        audioBytesWritten = 0L
        failure = null
        startElapsedRealtime = SystemClock.elapsedRealtime()
        recording = true

        workerThread = thread(start = true, name = "VoiceCloneRecorder") {
            FileOutputStream(wavFile).use { outputStream ->
                writePlaceholderHeader(outputStream)
                try {
                    recorder.startRecording()
                    val buffer = ByteArray(bufferSize)
                    while (recording) {
                        val read = recorder.read(buffer, 0, buffer.size)
                        if (read > 0) {
                            outputStream.write(buffer, 0, read)
                            audioBytesWritten += read
                        }
                    }
                } catch (throwable: Throwable) {
                    failure = throwable
                } finally {
                    try {
                        recorder.stop()
                    } catch (_: Throwable) {
                    }
                }
            }
            patchHeader(wavFile, audioBytesWritten)
            recorder.release()
        }
    }

    fun stop(): RecordingResult {
        if (!recording) {
            throw IllegalStateException(currentAppText(
                "当前没有进行中的录音",
                "No recording is currently in progress."
            ))
        }
        recording = false
        workerThread?.join(4_000L)
        val file = outputFile ?: throw IllegalStateException(currentAppText(
            "录音文件不存在",
            "Recording file does not exist."
        ))
        val result = RecordingResult(
            file = file,
            durationMs = (SystemClock.elapsedRealtime() - startElapsedRealtime).coerceAtLeast(0L),
            audioBytes = audioBytesWritten
        )
        val error = failure
        clearRuntimeState()
        if (error != null) {
            file.delete()
            throw IllegalStateException(error.message ?: currentAppText(
                "录音失败，请重试",
                "Recording failed. Please try again."
            ))
        }
        return result
    }

    fun cancel() {
        if (!recording) {
            outputFile?.takeIf(File::exists)?.delete()
            clearRuntimeState()
            return
        }
        recording = false
        workerThread?.join(4_000L)
        outputFile?.takeIf(File::exists)?.delete()
        clearRuntimeState()
    }

    private fun clearRuntimeState() {
        audioRecord = null
        workerThread = null
        outputFile = null
        audioBytesWritten = 0L
        startElapsedRealtime = 0L
        failure = null
        recording = false
    }

    private fun writePlaceholderHeader(outputStream: FileOutputStream) {
        outputStream.write(ByteArray(WavHeaderBytes))
    }

    private fun patchHeader(file: File, audioBytes: Long) {
        if (!file.exists()) {
            return
        }
        RandomAccessFile(file, "rw").use { randomAccessFile ->
            val totalDataLen = audioBytes + 36L
            val byteRate = SampleRateHz * ChannelCount * BitsPerSample / 8
            randomAccessFile.seek(0L)
            randomAccessFile.writeBytes("RIFF")
            randomAccessFile.writeInt(Integer.reverseBytes(totalDataLen.toInt()))
            randomAccessFile.writeBytes("WAVE")
            randomAccessFile.writeBytes("fmt ")
            randomAccessFile.writeInt(Integer.reverseBytes(16))
            randomAccessFile.writeShort(java.lang.Short.reverseBytes(1.toShort()).toInt())
            randomAccessFile.writeShort(java.lang.Short.reverseBytes(ChannelCount.toShort()).toInt())
            randomAccessFile.writeInt(Integer.reverseBytes(SampleRateHz))
            randomAccessFile.writeInt(Integer.reverseBytes(byteRate))
            randomAccessFile.writeShort(
                java.lang.Short.reverseBytes((ChannelCount * BitsPerSample / 8).toShort()).toInt()
            )
            randomAccessFile.writeShort(java.lang.Short.reverseBytes(BitsPerSample.toShort()).toInt())
            randomAccessFile.writeBytes("data")
            randomAccessFile.writeInt(Integer.reverseBytes(audioBytes.toInt()))
        }
    }
}
