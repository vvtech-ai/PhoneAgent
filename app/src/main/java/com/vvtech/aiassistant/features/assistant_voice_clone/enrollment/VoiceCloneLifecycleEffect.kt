package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState

@Composable
internal fun VoiceCloneLifecycleEffect(
    submissionState: VoiceCloneSubmissionState,
    onProcessBackgrounded: () -> Unit,
    onCompletedProcessForegrounded: () -> Unit
) {
    val currentSubmissionState by rememberUpdatedState(submissionState)
    val currentBackgroundedCallback by rememberUpdatedState(onProcessBackgrounded)
    val currentForegroundedCallback by rememberUpdatedState(onCompletedProcessForegrounded)
    DisposableEffect(Unit) {
        val lifecycle = ProcessLifecycleOwner.get().lifecycle
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> {
                    if (shouldInterruptVoiceCloneOnBackground(currentSubmissionState)) {
                        currentBackgroundedCallback()
                    }
                }
                Lifecycle.Event.ON_START -> {
                    if (shouldCompleteVoiceCloneOnForeground(currentSubmissionState)) {
                        currentForegroundedCallback()
                    }
                }
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
}

internal fun shouldInterruptVoiceCloneOnBackground(
    submissionState: VoiceCloneSubmissionState
): Boolean = submissionState != VoiceCloneSubmissionState.READY

internal fun shouldCompleteVoiceCloneOnForeground(
    submissionState: VoiceCloneSubmissionState
): Boolean = submissionState == VoiceCloneSubmissionState.READY
