package com.vvtech.aiassistant.features.assistant_recording

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.data.repository.recording.CallRecordingInfo

internal enum class CallRecordingPlaybackState {
    Idle,
    Loading,
    Playing,
    Paused,
    Ended,
    Error,
}

internal enum class CallRecordingControlIcon {
    Play,
    Pause,
    Loading,
    Retry,
}

internal data class CallRecordingUiState(
    val callId: String,
    val playbackState: CallRecordingPlaybackState = CallRecordingPlaybackState.Idle,
    val durationMillis: Long? = null,
    val playbackPositionMillis: Long = 0L,
    val contentType: String? = null,
    val message: String? = null,
)

internal fun CallRecordingUiState.controlIcon(): CallRecordingControlIcon = when (playbackState) {
    CallRecordingPlaybackState.Loading -> CallRecordingControlIcon.Loading
    CallRecordingPlaybackState.Playing -> CallRecordingControlIcon.Pause
    CallRecordingPlaybackState.Error -> CallRecordingControlIcon.Retry
    else -> CallRecordingControlIcon.Play
}

internal fun CallRecordingUiState.controlClickLabel(): String = when (controlIcon()) {
    CallRecordingControlIcon.Loading -> "录音加载中"
    CallRecordingControlIcon.Pause -> "暂停本次电话录音"
    CallRecordingControlIcon.Retry -> "录音加载失败，重新加载"
    CallRecordingControlIcon.Play -> "播放本次电话录音"
}

internal fun callRecordingAnchor(result: CallResultPayload?): String? =
    result
        ?.metadata
        ?.get("callId")
        ?.trim()
        ?.takeIf(String::isNotEmpty)

internal fun CallRecordingUiState.withMetadata(
    info: CallRecordingInfo,
): CallRecordingUiState {
    if (info.callId != callId) return this
    return copy(
        durationMillis = info.durationMillis ?: durationMillis,
        contentType = info.contentType ?: contentType,
    )
}

internal fun CallRecordingInfo.isProcessing(): Boolean =
    status.trim().uppercase() in setOf("RECORDING", "PROCESSING")
