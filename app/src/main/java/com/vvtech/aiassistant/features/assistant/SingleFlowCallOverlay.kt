package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowMockCallOverlay as SingleFlowMockCallOverlayContent

@Composable
internal fun SingleFlowMockCallOverlay(
    callVisible: Boolean,
    callName: String,
    callSub: String,
    callStatus: String,
    callSeconds: Int,
    callTranscripts: List<String>,
    callListState: LazyListState,
    callMuted: Boolean,
    callSpeaker: Boolean,
    onToggleMuted: () -> Unit,
    onToggleSpeaker: () -> Unit,
    onEndCall: () -> Unit
) {
    SingleFlowMockCallOverlayContent(
        callVisible = callVisible,
        callName = callName,
        callSub = callSub,
        callStatus = callStatus,
        callSeconds = callSeconds,
        callTranscripts = callTranscripts,
        callListState = callListState,
        callMuted = callMuted,
        callSpeaker = callSpeaker,
        onToggleMuted = onToggleMuted,
        onToggleSpeaker = onToggleSpeaker,
        onEndCall = onEndCall
    )
}
