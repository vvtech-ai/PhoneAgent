package com.vvtech.aiassistant.features.assistant_calls

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
import androidx.compose.foundation.layout.statusBarsPadding
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantCallPhase
import com.vvtech.aiassistant.callengine.AssistantClientCallState

@Composable
internal fun AssistantClientSipCallPage(
    state: AssistantClientCallState,
    onToggleMuted: () -> Unit,
    onToggleSpeaker: () -> Unit,
    onDtmf: (Char) -> Unit,
    onHangup: () -> Unit
) {
    var showDialPad by remember { mutableStateOf(false) }
    val translation = state.request?.mode == AssistantCallMode.TRANSLATION
    BackHandler(onBack = {})
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF0D1B38), Color(0xFF172B52), Color(0xFF142749))
                )
            )
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(24.dp))
        Box(
            modifier = Modifier
                .size(88.dp)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(Color(0xFF78A7FF), Color(0xFF386FF8)))),
            contentAlignment = Alignment.Center
        ) {
            Text("A", color = Color.White, fontSize = 38.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(16.dp))
        Text(
            text = state.request?.let { it.displayName.ifBlank { it.phoneNumber } }.orEmpty(),
            color = Color.White,
            fontSize = 26.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(14.dp))
        CallStateChip(state.phase, translation)
        Spacer(Modifier.height(12.dp))
        Text(
            text = formatCallSeconds(state.elapsedSeconds),
            color = Color(0xFFC2CCE0),
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(Modifier.height(18.dp))
        if (translation) {
            AssistantClientCallTranscriptThread(
                transcripts = state.transcripts,
                modifier = Modifier.weight(1f)
            )
        } else {
            Box(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = stringResource(R.string.sip_call_in_progress),
                    color = Color(0xFF9AA9C3),
                    fontSize = 17.sp
                )
            }
        }
        if (showDialPad) {
            AssistantCallDtmfPad(onDtmf = onDtmf)
            Spacer(Modifier.height(18.dp))
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            CallControl(
                label = stringResource(R.string.sip_call_muted),
                icon = if (state.muted) Icons.Default.MicOff else Icons.Default.Mic,
                active = state.muted,
                onClick = onToggleMuted
            )
            CallControl(
                label = stringResource(R.string.sip_call_dialpad),
                icon = Icons.Default.Dialpad,
                active = showDialPad,
                onClick = { showDialPad = !showDialPad }
            )
            CallControl(
                label = stringResource(R.string.sip_call_speaker),
                icon = if (state.speakerEnabled) Icons.Default.VolumeUp else Icons.Default.VolumeOff,
                active = state.speakerEnabled,
                onClick = onToggleSpeaker
            )
        }
        Spacer(Modifier.height(28.dp))
        CallControl(
            label = stringResource(R.string.sip_call_hangup),
            icon = Icons.Default.CallEnd,
            active = true,
            danger = true,
            onClick = onHangup
        )
        Spacer(Modifier.height(22.dp))
    }
}

@Composable
private fun CallStateChip(phase: AssistantCallPhase, translation: Boolean) {
    val text = when (phase) {
        AssistantCallPhase.REGISTERING -> stringResource(R.string.sip_phase_registering)
        AssistantCallPhase.DIALING -> stringResource(R.string.sip_phase_dialing)
        AssistantCallPhase.RINGING -> stringResource(R.string.sip_phase_ringing)
        AssistantCallPhase.CONNECTED -> stringResource(R.string.sip_phase_connected)
        AssistantCallPhase.TRANSLATING -> stringResource(R.string.sip_phase_translating)
        AssistantCallPhase.FAILED -> stringResource(R.string.sip_phase_failed)
        AssistantCallPhase.ENDED -> stringResource(R.string.sip_phase_ended)
        AssistantCallPhase.IDLE -> ""
    }
    val color = if (phase == AssistantCallPhase.FAILED) Color(0xFFFF6868) else Color(0xFF42D984)
    Text(
        text = if (translation && phase == AssistantCallPhase.CONNECTED) {
            stringResource(R.string.sip_translation_preparing)
        } else {
            text
        },
        modifier = Modifier
            .clip(RoundedCornerShape(28.dp))
            .background(color.copy(alpha = 0.16f))
            .padding(horizontal = 20.dp, vertical = 9.dp),
        color = color,
        fontSize = 15.sp,
        fontWeight = FontWeight.Bold
    )
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
                .size(68.dp)
                .clip(CircleShape)
                .background(
                    when {
                        danger -> Color(0xFFFF3B35)
                        active -> Color(0xFF506489)
                        else -> Color(0xFF31476F)
                    }
                )
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = label, tint = Color.White, modifier = Modifier.size(29.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text(label, color = Color(0xFFDCE3F0), fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

private fun formatCallSeconds(seconds: Int): String =
    "%02d:%02d".format(seconds / 60, seconds % 60)
