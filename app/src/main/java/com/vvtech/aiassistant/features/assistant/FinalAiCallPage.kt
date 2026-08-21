package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_calls.aiCallDisplayNumber
import com.vvtech.aiassistant.features.assistant_calls.aiCallStatusWithDuration
import com.vvtech.aiassistant.features.assistant_ui.AiCallAudioSourceSheet
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.assistant_ui.displayLabel
import com.vvtech.aiassistant.features.assistant_ui.iconResource
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun FinalAiCallPageV3(
    targetName: String,
    phoneNumber: String,
    callModelTitle: String = AssistantCallModelDisplayNames.Qwen,
    seconds: Int,
    callData: CallPageData,
    callUiMode: CallUiMode,
    handoffInFlight: Boolean,
    callMonitorState: CallMonitorPlaybackState,
    callMonitorAudioRouteState: CallMonitorAudioRouteState,
    onHangup: () -> Unit,
    onMonitorToggle: () -> Unit,
    onAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
) {
    val rawDisplayName = callData.name.ifBlank { targetName }
    val displayName = currentAppText(
        rawDisplayName,
        sanitizeUserFacingNetworkText(rawDisplayName, VoiceLanguage.English)
    )
    val displayNumber = aiCallDisplayNumber(phoneNumber.ifBlank { callData.sub })
    val displayStatus = aiCallStatusWithDuration(callData.callState, seconds)
    val transcriptCards = finalCallTranscriptCards(
        transcript = callData.transcript,
        includePlaceholder = callData.callState.trim().equals("CONNECTED", ignoreCase = true)
    )
    val callTranscriptListState = rememberLazyListState()
    val isListening = callMonitorState == CallMonitorPlaybackState.Playing
    val monitorButtonEnabled =
        callMonitorState != CallMonitorPlaybackState.Connecting &&
            callMonitorState != CallMonitorPlaybackState.Reconnecting
    val audioSourceEnabled = callMonitorState.allowsAudioRouteSelection()
    var showAudioSourceSheet by remember { mutableStateOf(false) }

    LaunchedEffect(transcriptCards) {
        if (transcriptCards.isNotEmpty()) {
            callTranscriptListState.animateScrollToItem(transcriptCards.lastIndex)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF101114), Color(0xFF151922), Color(0xFF0B0D12))
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp)
                .padding(top = 70.dp, bottom = 14.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = displayName,
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color.White,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.ExtraBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (displayNumber.isNotBlank()) {
                    Text(
                        text = displayNumber,
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color.White.copy(alpha = 0.70f),
                        fontSize = 15.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Text(
                    text = displayStatus,
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color.White.copy(alpha = 0.92f),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            LazyColumn(
                state = callTranscriptListState,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 14.dp)
                    .weight(1f),
                contentPadding = PaddingValues(bottom = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(transcriptCards) { card ->
                    FinalAiCallTranscriptCard(label = card.first, text = card.second)
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp, bottom = 4.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                FinalAiCallControl(
                    label = stringResource(R.string.ai_call_monitor),
                    iconResource = if (isListening) {
                        R.drawable.ic_agent_call_listen_off
                    } else {
                        R.drawable.ic_agent_call_listen
                    },
                    enabled = monitorButtonEnabled,
                    contentDescription = if (isListening) {
                        stringResource(R.string.ai_call_monitor_stop)
                    } else {
                        stringResource(R.string.ai_call_monitor_start)
                    },
                    onClick = onMonitorToggle
                )
                FinalAiCallControl(
                    label = stringResource(R.string.ai_call_hangup),
                    iconResource = R.drawable.ic_agent_call_hangup,
                    danger = true,
                    onClick = onHangup
                )
                FinalAiCallControl(
                    label = callMonitorAudioRouteState.selected.displayLabel(),
                    iconResource = callMonitorAudioRouteState.selected.iconResource(),
                    enabled = audioSourceEnabled,
                    contentDescription = stringResource(
                        R.string.ai_call_audio_source_content_description,
                        callMonitorAudioRouteState.selected.displayLabel()
                    ),
                    onClick = { showAudioSourceSheet = true }
                )
            }
        }
        if (showAudioSourceSheet && audioSourceEnabled) {
            AiCallAudioSourceSheet(
                routeState = callMonitorAudioRouteState,
                onDismiss = { showAudioSourceSheet = false },
                onRouteSelect = onAudioRouteSelect
            )
        }
    }
}

@Composable
internal fun FinalCallWaveBars(active: Boolean) {
    val transition = rememberInfiniteTransition(label = "finalCallWave")
    val scaleA by transition.animateFloat(
        initialValue = 0.42f,
        targetValue = if (active) 1.12f else 0.62f,
        animationSpec = infiniteRepeatable(
            animation = tween(if (active) 620 else 1100),
            repeatMode = RepeatMode.Reverse
        ),
        label = "finalCallWaveA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.5f,
        targetValue = if (active) 1.24f else 0.72f,
        animationSpec = infiniteRepeatable(
            animation = tween(if (active) 760 else 1300, delayMillis = 90),
            repeatMode = RepeatMode.Reverse
        ),
        label = "finalCallWaveB"
    )
    val heights = listOf(16, 28, 48, 72, 98, 72, 48, 28, 16)
    val scales = listOf(scaleA, scaleB, (scaleA + scaleB) / 2f, scaleA, scaleB, scaleA, (scaleA + scaleB) / 2f, scaleB, scaleA)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        heights.forEachIndexed { index, height ->
            Box(
                modifier = Modifier
                    .width(6.dp)
                    .height(height.dp)
                    .graphicsLayer(scaleY = scales[index])
                    .clip(RoundedCornerShape(999.dp))
                    .background(Color(0xFF34C759))
            )
        }
    }
}

@Composable
internal fun FinalAiCallTranscriptCard(
    label: String,
    text: String
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White.copy(alpha = 0.08f),
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.08f)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 15.dp)) {
            Text(
                text = label,
                color = Color.White.copy(alpha = 0.56f),
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp
            )
            Text(
                text = text,
                modifier = Modifier.padding(top = 8.dp),
                color = Color.White,
                fontSize = 14.sp,
                lineHeight = 21.sp
            )
        }
    }
}

@Composable
internal fun FinalAiCallControl(
    label: String,
    iconResource: Int,
    enabled: Boolean = true,
    contentDescription: String = label,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .width(72.dp)
            .alpha(if (enabled) 1f else 0.38f),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Surface(
            modifier = Modifier
                .size(52.dp)
                .clickable(enabled = enabled, onClick = onClick),
            color = if (danger) Color(0xFFEF4444) else Color(0xFF252A34),
            shape = CircleShape,
            elevation = 0.dp
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    painter = painterResource(iconResource),
                    contentDescription = contentDescription,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
        Text(
            text = label,
            modifier = Modifier.padding(top = 8.dp),
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

internal fun finalCallAvatarText(name: String): String {
    val trimmed = name.trim()
    if (trimmed.isBlank()) return "AI"
    val firstCodePoint = trimmed.codePointAt(0)
    return String(Character.toChars(firstCodePoint)).uppercase(Locale.getDefault())
}

internal fun finalCallTranscriptCards(
    transcript: List<TranscriptLine>,
    includePlaceholder: Boolean = true
): List<Pair<String, String>> {
    val cards = transcript
        .filter { it.role != TranscriptRole.Note }
        .map { line ->
        val label = when (line.role) {
            TranscriptRole.Assistant -> "AI"
            TranscriptRole.Remote -> currentAppText("对方", "Other Party")
            TranscriptRole.Note -> currentAppText("通话", "Calls")
        }
        label to currentAppText(
            line.text,
            sanitizeCallTranscriptDisplayText(line.text, VoiceLanguage.English)
        )
    }
    return cards.ifEmpty {
        if (includePlaceholder) {
            listOf(
                currentAppText("实时对话记录", "Live Transcript") to
                    currentAppText("等待实时通话转写...", "Waiting for live call transcription...")
            )
        } else {
            emptyList()
        }
    }
}
