package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant.sfFormatCallTime

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
    if (!callVisible) return

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    listOf(Color(0xFF141820), Color(0xFF101218))
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 22.dp)
                .navigationBarsPadding()
        ) {
            MockCallOverlayBadge()
            Spacer(modifier = Modifier.height(26.dp))
            MockCallOverlayHeader(
                callName = callName,
                callSub = callSub,
                callStatus = callStatus,
                callSeconds = callSeconds
            )
            Spacer(modifier = Modifier.height(16.dp))
            MockCallTranscriptList(
                callTranscripts = callTranscripts,
                callListState = callListState,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            )
            Spacer(modifier = Modifier.height(14.dp))
            MockCallControlRow(
                callMuted = callMuted,
                callSpeaker = callSpeaker,
                onToggleMuted = onToggleMuted,
                onToggleSpeaker = onToggleSpeaker,
                onEndCall = onEndCall
            )
        }
    }
}

@Composable
private fun MockCallOverlayBadge() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            shape = RoundedCornerShape(999.dp),
            color = Color.White.copy(alpha = 0.12f),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.22f))
        ) {
            Text(
                text = "Using user voice · Running agent task",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
            )
        }
    }
}

@Composable
private fun MockCallOverlayHeader(
    callName: String,
    callSub: String,
    callStatus: String,
    callSeconds: Int
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Surface(
            modifier = Modifier.size(84.dp),
            shape = CircleShape,
            color = Color(0xFF1E2A3B)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = callName.take(1),
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 30.sp
                )
            }
        }
        Text(
            text = callName,
            color = Color.White,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 14.dp)
        )
        Text(
            text = callSub,
            color = Color.White.copy(alpha = 0.72f),
            fontSize = 14.sp,
            modifier = Modifier.padding(top = 4.dp)
        )
        Text(
            text = callStatus,
            color = Color(0xFFA5D0FF),
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 8.dp)
        )
        Text(
            text = sfFormatCallTime(callSeconds),
            color = Color.White.copy(alpha = 0.9f),
            fontSize = 14.sp,
            modifier = Modifier.padding(top = 3.dp)
        )
    }
}

@Composable
private fun MockCallTranscriptList(
    callTranscripts: List<String>,
    callListState: LazyListState,
    modifier: Modifier
) {
    LazyColumn(
        state = callListState,
        modifier = modifier,
        contentPadding = PaddingValues(bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(callTranscripts) { line ->
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = Color.White.copy(alpha = 0.08f),
                border = BorderStroke(1.dp, Color.White.copy(alpha = 0.12f))
            ) {
                Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                    Text(
                        text = "Call Transcript",
                        color = Color.White.copy(alpha = 0.55f),
                        fontSize = 11.sp,
                        letterSpacing = 0.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = line,
                        color = Color.White.copy(alpha = 0.92f),
                        fontSize = 14.sp,
                        lineHeight = 21.sp,
                        modifier = Modifier.padding(top = 6.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun MockCallControlRow(
    callMuted: Boolean,
    callSpeaker: Boolean,
    onToggleMuted: () -> Unit,
    onToggleSpeaker: () -> Unit,
    onEndCall: () -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        SfCallControlButton(
            modifier = Modifier.weight(1f),
            title = if (callMuted) currentAppText("已静音", "Muted") else currentAppText("静音", "Mute"),
            icon = "🎙",
            active = callMuted
        ) {
            onToggleMuted()
        }
        SfCallControlButton(
            modifier = Modifier.weight(1f),
            title = if (callSpeaker) currentAppText("扬声器开", "Speaker On") else currentAppText("扬声器关", "Speaker Off"),
            icon = "🔊",
            active = callSpeaker
        ) {
            onToggleSpeaker()
        }
        SfCallControlButton(
            modifier = Modifier.weight(1f),
            title = "End",
            icon = "☎",
            danger = true
        ) {
            onEndCall()
        }
    }
}
