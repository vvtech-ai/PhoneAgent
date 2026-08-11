package com.vvtech.aiassistant.features.assistant_recording

import android.app.Application
import com.vvtech.aiassistant.data.repository.recording.CallRecordingInfo
import com.vvtech.aiassistant.data.repository.recording.CallRecordingPlaybackSource
import com.vvtech.aiassistant.data.repository.recording.CallRecordingRepository
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class CallRecordingViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun metadataFailureKeepsBubbleIdleAndPlaybackClickable() =
        runTest(mainDispatcherRule.dispatcher) {
            val repository = FakeRecordingRepository(
                getMetadata = { throw IOException("offline") },
                getPlaybackSource = { throw IOException("offline") },
            )
            val player = FakeRecordingPlaybackEngine()
            val viewModel = CallRecordingViewModel("call-1", repository, player)

            advanceUntilIdle()

            assertEquals(CallRecordingPlaybackState.Idle, viewModel.state.value.playbackState)
            assertEquals("点击播放", viewModel.state.value.displayDuration())
            assertNull(viewModel.state.value.message)

            viewModel.togglePlayback()
            advanceUntilIdle()

            assertEquals(CallRecordingPlaybackState.Error, viewModel.state.value.playbackState)
            assertEquals("录音加载失败", viewModel.state.value.displayDuration())
            assertEquals(1, repository.playbackSourceRequests)
            assertEquals(1, player.finishLoadingCalls)
        }

    @Test
    fun failedMetadataStatusDoesNotPreventActualPlayback() =
        runTest(mainDispatcherRule.dispatcher) {
            val repository = FakeRecordingRepository(
                getMetadata = {
                    recordingInfo(status = "FAILED", durationMillis = 65_000L)
                },
                getPlaybackSource = { playbackSource() },
            )
            val player = FakeRecordingPlaybackEngine(durationMillis = 65_000L)
            val viewModel = CallRecordingViewModel("call-1", repository, player)

            advanceUntilIdle()
            viewModel.togglePlayback()
            runCurrent()

            assertEquals(CallRecordingPlaybackState.Loading, viewModel.state.value.playbackState)
            assertEquals(1, player.playCalls)

            player.startPlayback()

            assertEquals(CallRecordingPlaybackState.Playing, viewModel.state.value.playbackState)
            assertEquals(65_000L, viewModel.state.value.durationMillis)
            viewModel.stopPlayback()
        }

    @Test
    fun lateMetadataResponseOnlyHydratesDurationWithoutOverwritingLoading() =
        runTest(mainDispatcherRule.dispatcher) {
            val metadata = CompletableDeferred<CallRecordingInfo>()
            val repository = FakeRecordingRepository(
                getMetadata = { metadata.await() },
                getPlaybackSource = { playbackSource() },
            )
            val player = FakeRecordingPlaybackEngine()
            val viewModel = CallRecordingViewModel("call-1", repository, player)

            runCurrent()
            viewModel.togglePlayback()
            runCurrent()
            assertEquals(CallRecordingPlaybackState.Loading, viewModel.state.value.playbackState)

            metadata.complete(recordingInfo(status = "EXPIRED", durationMillis = 32_000L))
            runCurrent()

            assertEquals(CallRecordingPlaybackState.Loading, viewModel.state.value.playbackState)
            assertEquals(32_000L, viewModel.state.value.durationMillis)
            assertEquals("录音加载中", viewModel.state.value.displayDuration())
            viewModel.stopPlayback()
        }

    @Test
    fun everyFailureWaitsForManualRetryAndRequestsFreshPlaybackSource() =
        runTest(mainDispatcherRule.dispatcher) {
            var failPlaybackSource = true
            val repository = FakeRecordingRepository(
                getMetadata = { recordingInfo(status = "LEGACY_MISSING") },
                getPlaybackSource = {
                    if (failPlaybackSource) throw IOException("recording unavailable")
                    playbackSource()
                },
            )
            val player = FakeRecordingPlaybackEngine()
            val viewModel = CallRecordingViewModel("call-1", repository, player)

            advanceUntilIdle()
            viewModel.togglePlayback()
            advanceUntilIdle()

            assertEquals(CallRecordingPlaybackState.Error, viewModel.state.value.playbackState)
            assertEquals(1, repository.playbackSourceRequests)

            failPlaybackSource = false
            viewModel.togglePlayback()
            runCurrent()

            assertEquals(CallRecordingPlaybackState.Loading, viewModel.state.value.playbackState)
            assertEquals(2, repository.playbackSourceRequests)
            assertEquals(1, player.playCalls)

            viewModel.togglePlayback()
            runCurrent()

            assertEquals(2, repository.playbackSourceRequests)
            assertEquals(1, player.playCalls)

            player.failPlayback()

            assertEquals(CallRecordingPlaybackState.Error, viewModel.state.value.playbackState)
            assertEquals(2, repository.playbackSourceRequests)

            viewModel.togglePlayback()
            runCurrent()

            assertEquals(CallRecordingPlaybackState.Loading, viewModel.state.value.playbackState)
            assertEquals(3, repository.playbackSourceRequests)
            assertTrue(player.playCalls >= 2)
            viewModel.stopPlayback()
        }

    private fun recordingInfo(
        status: String,
        durationMillis: Long? = null,
    ) = CallRecordingInfo(
        callId = "call-1",
        status = status,
        durationMillis = durationMillis,
        contentType = "audio/wav",
    )

    private fun playbackSource() = CallRecordingPlaybackSource(
        url = "https://example.test/recording.wav",
        contentType = "audio/wav",
    )
}

@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    val dispatcher: TestDispatcher = StandardTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(dispatcher)
    }

    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}

private class FakeRecordingRepository(
    private val getMetadata: suspend () -> CallRecordingInfo,
    private val getPlaybackSource: suspend () -> CallRecordingPlaybackSource,
) : CallRecordingRepository {
    var playbackSourceRequests: Int = 0
        private set

    override suspend fun getRecording(callId: String): CallRecordingInfo = getMetadata()

    override suspend fun createPlaybackSource(callId: String): CallRecordingPlaybackSource {
        playbackSourceRequests += 1
        return getPlaybackSource()
    }
}

private class FakeRecordingPlaybackEngine(
    private val durationMillis: Long? = null,
) : CallRecordingPlaybackEngine {
    var finishLoadingCalls: Int = 0
        private set
    var playCalls: Int = 0
        private set

    private var started: (() -> Unit)? = null
    private var failed: (() -> Unit)? = null

    override fun beginLoading(onStopped: () -> Unit) = Unit

    override fun finishLoading() {
        finishLoadingCalls += 1
    }

    override fun play(
        source: CallRecordingPlaybackSource,
        onStarted: () -> Unit,
        onCompleted: () -> Unit,
        onFailed: () -> Unit,
        onPaused: () -> Unit,
        onStopped: () -> Unit,
    ) {
        playCalls += 1
        started = onStarted
        failed = onFailed
    }

    fun startPlayback() {
        started?.invoke()
    }

    fun failPlayback() {
        failed?.invoke()
    }

    override fun pause(): Boolean = false

    override fun resume(): Boolean = false

    override fun stop() = Unit

    override fun currentPositionMillis(): Long? = 0L

    override fun durationMillis(): Long? = durationMillis
}
