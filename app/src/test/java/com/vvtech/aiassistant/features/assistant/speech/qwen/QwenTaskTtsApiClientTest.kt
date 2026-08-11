package com.vvtech.aiassistant.features.assistant.speech.qwen

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.yield
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class QwenTaskTtsApiClientTest {

    @Test
    fun closeNowClosesActiveSocketWithReasonAndResumesPendingSynthesis() = runBlocking {
        val socket = RecordingWebSocket()
        var capturedListener: WebSocketListener? = null
        val client = QwenTaskTtsApiClient(
            socketFactory = { _: Request, listener: WebSocketListener ->
                capturedListener = listener
                socket
            },
            delayScheduler = NoOpDelayScheduler,
            logSink = NoOpLogSink
        )

        val job = launch {
            client.synthesize(
                text = "hello",
                speaker = "speaker",
                onAudioChunk = {},
                onComplete = {},
                onError = { throw AssertionError("close should not report synthesize error", it) }
            )
        }
        while (capturedListener == null) {
            yield()
        }

        client.closeNow("pause_voice_input")
        job.join()

        assertNotNull(capturedListener)
        assertEquals(1000, socket.closeCode)
        assertEquals("pause_voice_input", socket.closeReason)
    }

    @Test
    fun firstAudioTimeoutReportsErrorClosesSocketAndResumesPendingSynthesis() = runBlocking {
        val socket = RecordingWebSocket()
        val scheduler = ManualDelayScheduler()
        var capturedError: Throwable? = null
        val client = QwenTaskTtsApiClient(
            socketFactory = { _: Request, _: WebSocketListener -> socket },
            delayScheduler = scheduler,
            logSink = NoOpLogSink
        )

        val job = launch {
            client.synthesize(
                text = "hello",
                speaker = "speaker",
                onAudioChunk = {},
                onComplete = {},
                onError = { capturedError = it }
            )
        }
        while (scheduler.pendingCount == 0) {
            yield()
        }

        scheduler.runAll()
        val completed = withTimeoutOrNull(250L) {
            job.join()
            true
        }
        if (completed != true) {
            client.closeNow("test_cleanup")
        }

        assertEquals(true, completed)
        assertNotNull(capturedError)
        assertTrue(capturedError?.message.orEmpty().contains("first_audio_timeout"))
        assertEquals(1000, socket.closeCode)
        assertEquals("first_audio_timeout", socket.closeReason)
    }

    @Test
    fun completionTimeoutAfterAudioSoftCompletesAndDoesNotReportError() = runBlocking {
        val socket = RecordingWebSocket()
        val scheduler = ManualDelayScheduler()
        var capturedListener: WebSocketListener? = null
        var capturedError: Throwable? = null
        var completeCount = 0
        var audioBytes = 0
        val client = QwenTaskTtsApiClient(
            socketFactory = { _: Request, listener: WebSocketListener ->
                capturedListener = listener
                socket
            },
            delayScheduler = scheduler,
            logSink = NoOpLogSink
        )

        val job = launch {
            client.synthesize(
                text = "hello",
                speaker = "speaker",
                onAudioChunk = { audioBytes += it.size },
                onComplete = { completeCount++ },
                onError = { capturedError = it }
            )
        }
        while (capturedListener == null || scheduler.pendingCount < 2) {
            yield()
        }

        capturedListener?.onMessage(socket, ByteString.of(*ByteArray(10_000) { 1 }))
        scheduler.runAll()
        val completed = withTimeoutOrNull(250L) {
            job.join()
            true
        }
        if (completed != true) {
            client.closeNow("test_cleanup")
        }

        assertEquals(true, completed)
        assertNull(capturedError)
        assertEquals(1, completeCount)
        assertEquals(10_000, audioBytes)
        assertEquals(1000, socket.closeCode)
        assertEquals("completion_timeout", socket.closeReason)
    }

    private class RecordingWebSocket : WebSocket {
        var closeCode: Int? = null
        var closeReason: String? = null

        override fun request(): Request = Request.Builder().url("ws://localhost/test").build()

        override fun queueSize(): Long = 0L

        override fun send(text: String): Boolean = true

        override fun send(bytes: ByteString): Boolean = true

        override fun close(code: Int, reason: String?): Boolean {
            closeCode = code
            closeReason = reason
            return true
        }

        override fun cancel() = Unit
    }

    private object NoOpDelayScheduler : QwenTaskTtsDelayScheduler {
        override fun removeCallbacks(runnable: Runnable) = Unit

        override fun postDelayed(runnable: Runnable, delayMillis: Long) = Unit
    }

    private class ManualDelayScheduler : QwenTaskTtsDelayScheduler {
        private val tasks = mutableListOf<Runnable>()

        val pendingCount: Int
            get() = tasks.size

        override fun removeCallbacks(runnable: Runnable) {
            tasks.remove(runnable)
        }

        override fun postDelayed(runnable: Runnable, delayMillis: Long) {
            tasks.add(runnable)
        }

        fun runAll() {
            val snapshot = tasks.toList()
            tasks.clear()
            snapshot.forEach { it.run() }
        }
    }

    private object NoOpLogSink : QwenTaskTtsLogSink {
        override fun i(tag: String, message: String) = Unit

        override fun d(tag: String, message: String) = Unit
    }
}
