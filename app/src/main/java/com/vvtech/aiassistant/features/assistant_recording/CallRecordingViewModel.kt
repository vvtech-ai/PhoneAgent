package com.vvtech.aiassistant.features.assistant_recording

import android.content.Context
import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.data.repository.recording.CallRecordingRepository
import com.vvtech.aiassistant.data.repository.recording.CallRecordingRepositoryProvider
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class CallRecordingViewModel(
    private val callId: String,
    private val repository: CallRecordingRepository,
    private val player: CallRecordingPlaybackEngine,
) : ViewModel() {
    private val mutableState = MutableStateFlow(CallRecordingUiState(callId = callId))
    val state: StateFlow<CallRecordingUiState> = mutableState.asStateFlow()

    private var metadataJob: Job? = null
    private var playbackJob: Job? = null
    private var progressJob: Job? = null

    init {
        refreshMetadata()
    }

    fun togglePlayback() {
        when (mutableState.value.playbackState) {
            CallRecordingPlaybackState.Playing -> {
                if (player.pause()) {
                    updatePlaybackProgress()
                    stopProgressTicker()
                    mutableState.update { it.copy(playbackState = CallRecordingPlaybackState.Paused) }
                }
            }
            CallRecordingPlaybackState.Paused -> {
                if (player.resume()) {
                    mutableState.update { it.copy(playbackState = CallRecordingPlaybackState.Playing) }
                    startProgressTicker()
                } else {
                    startPlayback()
                }
            }
            CallRecordingPlaybackState.Loading -> Unit
            else -> startPlayback()
        }
    }

    fun stopPlayback() {
        playbackJob?.cancel()
        stopProgressTicker()
        player.stop()
        mutableState.update { current ->
            current.copy(
                playbackState = CallRecordingPlaybackState.Idle,
                playbackPositionMillis = 0L,
                message = null,
            )
        }
    }

    fun onHostStarted() {
        if (metadataJob?.isActive != true) refreshMetadata()
    }

    fun onHostStopped() {
        // A LazyColumn item can leave composition while its recording keeps playing.
        // Playback cleanup belongs to PureVoiceCallRecordingPlaybackHost.
        metadataJob?.cancel()
    }

    private fun refreshMetadata() {
        metadataJob?.cancel()
        metadataJob = viewModelScope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            do {
                val info = try {
                    repository.getRecording(callId)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (throwable: Throwable) {
                    AppFileLogger.w(
                        Tag,
                        "CALL_RECORDING metadata_unavailable callId=$callId " +
                            "stateUnchanged=true exceptionType=${throwable.javaClass.simpleName}",
                        throwable,
                    )
                    return@launch
                }
                mutableState.update { current -> current.withMetadata(info) }
                if (!info.isProcessing()) {
                    return@launch
                }
                delay(PollIntervalMillis)
            } while (SystemClock.elapsedRealtime() - startedAt < MaxPollingMillis)
        }
    }

    private fun startPlayback() {
        val isManualRetry =
            mutableState.value.playbackState == CallRecordingPlaybackState.Error
        playbackJob?.cancel()
        playbackJob = viewModelScope.launch {
            val requestVersion =
                CallRecordingPlaybackControl.beginPlaybackRequest()
            player.beginLoading {
                markPlaybackInterrupted()
            }
            mutableState.update {
                it.copy(
                    playbackState = CallRecordingPlaybackState.Loading,
                    message = null,
                )
            }
            AppFileLogger.i(
                Tag,
                "CALL_RECORDING load_started callId=$callId manualRetry=$isManualRetry",
            )
            val source = try {
                repository.createPlaybackSource(callId)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (throwable: Throwable) {
                if (!CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion)) {
                    markPlaybackInterrupted()
                    return@launch
                }
                player.finishLoading()
                AppFileLogger.w(
                    Tag,
                    "CALL_RECORDING load_failed callId=$callId stage=playback_source " +
                        "exceptionType=${throwable.javaClass.simpleName}",
                    throwable,
                )
                mutableState.update {
                    it.copy(
                        playbackState = CallRecordingPlaybackState.Error,
                        message = "录音加载失败",
                    )
                }
                return@launch
            }
            if (!CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion)) {
                markPlaybackInterrupted()
                return@launch
            }
            player.play(
                source = source,
                onStarted = {
                    AppFileLogger.i(
                        Tag,
                        "CALL_RECORDING playback_started callId=$callId",
                    )
                    mutableState.update {
                        it.copy(
                            playbackState = CallRecordingPlaybackState.Playing,
                            durationMillis = player.durationMillis() ?: it.durationMillis,
                            playbackPositionMillis = 0L,
                            message = null,
                        )
                    }
                    startProgressTicker()
                },
                onCompleted = {
                    stopProgressTicker()
                    mutableState.update {
                        it.copy(
                            playbackState = CallRecordingPlaybackState.Ended,
                            playbackPositionMillis = 0L,
                            message = null,
                        )
                    }
                },
                onFailed = {
                    stopProgressTicker()
                    handlePlayerFailure(requestVersion)
                },
                onPaused = {
                    updatePlaybackProgress()
                    stopProgressTicker()
                    mutableState.update {
                        it.copy(playbackState = CallRecordingPlaybackState.Paused, message = null)
                    }
                },
                onStopped = {
                    stopProgressTicker()
                    mutableState.update {
                        it.copy(
                            playbackState = CallRecordingPlaybackState.Idle,
                            playbackPositionMillis = 0L,
                            message = null,
                        )
                    }
                },
            )
        }
    }

    private fun handlePlayerFailure(requestVersion: Long) {
        if (!CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion)) {
            markPlaybackInterrupted()
            return
        }
        AppFileLogger.w(
            Tag,
            "CALL_RECORDING load_failed callId=$callId stage=media_player",
        )
        mutableState.update {
            it.copy(
                playbackState = CallRecordingPlaybackState.Error,
                message = "录音加载失败",
            )
        }
    }

    private fun markPlaybackInterrupted() {
        stopProgressTicker()
        mutableState.update { current ->
            current.copy(
                playbackState = CallRecordingPlaybackState.Idle,
                playbackPositionMillis = 0L,
                message = null,
            )
        }
    }

    override fun onCleared() {
        metadataJob?.cancel()
        playbackJob?.cancel()
        stopProgressTicker()
        player.stop()
        super.onCleared()
    }

    private companion object {
        const val Tag = "CallRecordingViewModel"
        const val PollIntervalMillis = 2_000L
        const val MaxPollingMillis = 60_000L
        const val PlaybackProgressIntervalMillis = 250L
    }

    private fun startProgressTicker() {
        progressJob?.cancel()
        progressJob = viewModelScope.launch {
            while (true) {
                updatePlaybackProgress()
                delay(PlaybackProgressIntervalMillis)
            }
        }
    }

    private fun stopProgressTicker() {
        progressJob?.cancel()
        progressJob = null
    }

    private fun updatePlaybackProgress() {
        val position = player.currentPositionMillis() ?: return
        val duration = player.durationMillis()
        mutableState.update {
            it.copy(
                durationMillis = duration ?: it.durationMillis,
                playbackPositionMillis = position.coerceAtLeast(0L),
            )
        }
    }
}

internal class CallRecordingViewModelFactory(
    context: Context,
    private val callId: String,
) : ViewModelProvider.Factory {
    private val appContext = context.applicationContext

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(CallRecordingViewModel::class.java))
        return CallRecordingViewModel(
            callId = callId,
            repository = CallRecordingRepositoryProvider.repository,
            player = CallRecordingPlayer(appContext, callId),
        ) as T
    }
}
