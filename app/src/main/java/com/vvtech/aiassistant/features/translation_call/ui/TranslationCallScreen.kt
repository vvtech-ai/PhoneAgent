package com.vvtech.aiassistant.features.translation_call.ui
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Dialpad
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.features.assistant_calls.formatDialHistoryNumberForDisplay
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiAction
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState

@Composable
internal fun TranslationCallScreen(
    state: TranslationCallUiState,
    onAction: (TranslationCallUiAction) -> Unit
) {
    var dialPadVisible by remember(state.callId) { mutableStateOf(false) }
    BackHandler(onBack = {})
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF0E1A33), Color(0xFF1A2C52))
                )
            )
            .navigationBarsPadding()
    ) {
        TranslationCallEnvironmentIndicator(
            environment = state.environment,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 10.dp, end = 18.dp)
                .testTag("translation-call-environment")
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 18.dp, top = 34.dp, end = 18.dp, bottom = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            TranslationCallIdentity(state)
            Spacer(Modifier.height(16.dp))
            TranslationTranscriptThread(
                transcripts = state.transcripts,
                hint = state.environment?.riskMessage.orEmpty(),
                modifier = Modifier.weight(1f)
            )
            if (dialPadVisible) {
                TranslationDtmfPad { onAction(TranslationCallUiAction.SendDtmf(it)) }
                Spacer(Modifier.height(12.dp))
            }
            TranslationCallControls(
                muted = state.muted,
                speakerEnabled = state.speakerEnabled,
                dialPadVisible = dialPadVisible,
                onMute = { onAction(TranslationCallUiAction.ToggleMuted) },
                onDialPad = { dialPadVisible = !dialPadVisible },
                onSpeaker = { onAction(TranslationCallUiAction.ToggleSpeaker) },
                onHangup = { onAction(TranslationCallUiAction.Hangup) }
            )
        }
    }
}
@Composable
private fun TranslationCallIdentity(state: TranslationCallUiState) {
    val number = formatDialHistoryNumberForDisplay(state.plan?.targetE164.orEmpty())
    val title = state.targetDisplayName.ifBlank { number }
    val level = state.environment?.overallStatus ?: TranslationEnvironmentState.Pending
    Text(
        text = title,
        color = Color.White,
        fontSize = 24.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1
    )
    Spacer(Modifier.height(12.dp))
    Text(
        text = state.phase.displayText(),
        modifier = Modifier
            .background(level.indicatorColor().copy(alpha = 0.14f), RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 5.dp),
        color = level.indicatorColor(),
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold
    )
    Spacer(Modifier.height(8.dp))
    Text(
        text = "%02d:%02d".format(state.elapsedSeconds / 60, state.elapsedSeconds % 60),
        color = Color.White.copy(alpha = 0.66f),
        fontSize = 13.sp,
        fontWeight = FontWeight.Bold
    )
}

@Composable
private fun TranslationTranscriptThread(
    transcripts: List<TranslationCallTranscriptItem>,
    hint: String,
    modifier: Modifier = Modifier
) {
    if (transcripts.isEmpty()) {
        Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(
                text = hint.ifBlank {
                    currentAppText("请清晰地说话，翻译内容会实时显示在这里", "Speak clearly. Translations will appear here in real time")
                },
                color = Color.White.copy(alpha = 0.56f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
        }
        return
    }
    val listState = rememberLazyListState()
    val latestScrollKey = translationTranscriptLatestScrollKey(transcripts)
    LaunchedEffect(latestScrollKey) {
        if (latestScrollKey.isNotEmpty()) {
            listState.scrollToItem(0)
        }
    }
    LazyColumn(
        modifier = modifier.fillMaxWidth().testTag("translation-call-transcripts"),
        state = listState,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        reverseLayout = true
    ) {
        items(transcripts.asReversed(), key = { it.segmentId }) { item ->
            TranslationTranscriptBubble(item)
        }
    }
}

@Composable
private fun TranslationTranscriptBubble(item: TranslationCallTranscriptItem) {
    val mine = item.sourceLeg.equals("user", true) || item.sourceLeg.equals("local", true)
    val lines = translationTranscriptLines(item)
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.82f)
                .background(
                    if (mine) Color(0xFF0A75DD) else Color.White.copy(alpha = 0.94f),
                    RoundedCornerShape(18.dp)
                )
                .padding(horizontal = 14.dp, vertical = 11.dp)
        ) {
            Text(
                text = lines.primary,
                color = if (mine) Color.White else Color(0xFF111111),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            lines.secondary?.let { translatedText ->
                Spacer(Modifier.height(6.dp))
                Text(
                    text = translatedText,
                    color = if (mine) Color.White.copy(alpha = 0.7f) else Color(0xB3111111),
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun TranslationCallControls(
    muted: Boolean,
    speakerEnabled: Boolean,
    dialPadVisible: Boolean,
    onMute: () -> Unit,
    onDialPad: () -> Unit,
    onSpeaker: () -> Unit,
    onHangup: () -> Unit
) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceAround) {
        CallControl(
            currentAppText("静音", "Mute"),
            if (muted) Icons.Default.MicOff else Icons.Default.Mic,
            muted,
            onClick = onMute
        )
        CallControl(currentAppText("拨号盘", "Keypad"), Icons.Default.Dialpad, dialPadVisible, onClick = onDialPad)
        CallControl(
            currentAppText("扬声器", "Speaker"),
            if (speakerEnabled) Icons.Default.VolumeUp else Icons.Default.VolumeOff,
            speakerEnabled,
            onClick = onSpeaker
        )
    }
    Spacer(Modifier.height(14.dp))
    CallControl(currentAppText("挂断", "Hang up"), Icons.Default.CallEnd, active = true, danger = true, onClick = onHangup)
}

@Composable
private fun CallControl(
    label: String,
    icon: ImageVector,
    active: Boolean,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(
                    when {
                        danger -> Color(0xFFFF3B35)
                        active -> Color(0xFF506489)
                        else -> Color(0xFF31476F)
                    }
                )
                .clickable(onClick = onClick)
                .testTag("translation-call-control-$label"),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = label, tint = Color.White, modifier = Modifier.size(28.dp))
        }
        Spacer(Modifier.height(7.dp))
        Text(label, color = Color(0xFFDCE3F0), fontSize = 13.sp)
    }
}

@Composable
private fun TranslationDtmfPad(onDtmf: (Char) -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(0.72f).background(Color(0x66192B50)),
        verticalArrangement = Arrangement.spacedBy(1.dp)
    ) {
        listOf("123", "456", "789", "*0#").forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                row.forEach { digit ->
                    Box(
                        modifier = Modifier.size(width = 64.dp, height = 42.dp)
                            .clickable { onDtmf(digit) },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(digit.toString(), color = Color.White, fontSize = 21.sp)
                    }
                }
            }
        }
    }
}
private fun TranslationCallPhase.displayText(): String = when (this) {
    TranslationCallPhase.Idle -> ""
    TranslationCallPhase.Preflight -> currentAppText("正在检测通话环境", "Checking call environment")
    TranslationCallPhase.Dialing -> currentAppText("正在拨号", "Dialing")
    TranslationCallPhase.Ringing -> currentAppText("正在振铃", "Ringing")
    TranslationCallPhase.Connected -> currentAppText("翻译准备中", "Preparing translation")
    TranslationCallPhase.Translating -> currentAppText("实时翻译 · 已接通", "Live translation connected")
    TranslationCallPhase.Ended -> currentAppText("通话已结束", "Call ended")
    TranslationCallPhase.Failed -> currentAppText("通话不可用", "Call unavailable")
}
