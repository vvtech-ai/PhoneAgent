package com.vvtech.aiassistant.features.assistant_recording

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
internal fun PureVoiceCallRecordingRoute(
    callId: String?,
    onCardRevealed: () -> Unit = {},
) {
    val stableCallId = callId?.trim()?.takeIf(String::isNotEmpty) ?: return
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val factory = remember(stableCallId) {
        CallRecordingViewModelFactory(context, stableCallId)
    }
    val recordingViewModel: CallRecordingViewModel = viewModel(
        key = "call-recording:$stableCallId",
        factory = factory,
    )
    val state by recordingViewModel.state.collectAsStateWithLifecycle()
    var revealReported by remember(stableCallId) { mutableStateOf(false) }

    DisposableEffect(recordingViewModel, lifecycleOwner) {
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            recordingViewModel.onHostStarted()
        } else {
            recordingViewModel.onHostStopped()
        }
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> recordingViewModel.onHostStarted()
                Lifecycle.Event.ON_STOP -> recordingViewModel.onHostStopped()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            recordingViewModel.onHostStopped()
        }
    }

    Box(
        modifier = Modifier.onSizeChanged { size ->
            if (size.height > 0 && !revealReported) {
                revealReported = true
                onCardRevealed()
            }
        }
    ) {
        PureVoiceCallRecordingCard(
            state = state,
            onTogglePlayback = recordingViewModel::togglePlayback,
        )
    }
}

@Composable
internal fun PureVoiceCallRecordingPlaybackHost(hostKey: Long) {
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner, hostKey) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                CallRecordingPlaybackControl.stopActiveForHost("lifecycle_on_stop")
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        if (!lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            CallRecordingPlaybackControl.stopActiveForHost("lifecycle_not_started")
        }
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            CallRecordingPlaybackControl.stopActiveForHost("pure_voice_host_disposed")
        }
    }
}
