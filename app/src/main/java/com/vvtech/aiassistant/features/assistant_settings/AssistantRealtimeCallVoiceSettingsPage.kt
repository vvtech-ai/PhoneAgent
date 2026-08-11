package com.vvtech.aiassistant.features.assistant_settings

import android.media.MediaPlayer
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.model.RealtimeCallVoiceItem
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse

internal data class AssistantRealtimeCallVoiceSettingsPageState(
    val response: RealtimeCallVoiceResponse?,
    val loading: Boolean,
    val switching: Boolean,
    val error: String?,
    val activeProvider: String,
    val cloneStatus: VoiceCloneStatusResponse?,
    val cloneLoading: Boolean,
    val cloneActionLoading: Boolean,
    val cloneError: String?
)

internal data class AssistantRealtimeCallVoiceSettingsPageCallbacks(
    val onBack: () -> Unit,
    val onSelectVoice: (String) -> Unit,
    val onSelectCloneVoice: () -> Unit,
    val onStartClone: () -> Unit
)

@Composable
internal fun AssistantRealtimeCallVoiceSettingsPage(
    state: AssistantRealtimeCallVoiceSettingsPageState,
    callbacks: AssistantRealtimeCallVoiceSettingsPageCallbacks
) {
    val context = LocalContext.current
    var playingVoice by remember { mutableStateOf<String?>(null) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    val isDoubao = state.activeProvider.equals("DOUBAO", ignoreCase = true)
    DisposableEffect(Unit) {
        onDispose { player?.release() }
    }
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "音色与声音克隆", onBack = callbacks.onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 16.dp)
        ) {
            if (state.loading && state.response == null) {
                item {
                    Text(
                        text = "加载中...",
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 14.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 13.sp
                    )
                }
            }
            if (!state.error.isNullOrBlank()) {
                item {
                    Text(
                        text = state.error,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 14.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp
                    )
                }
            }
            if (!isDoubao) {
                item {
                    AssistantRealtimeCallCloneVoiceSection(
                        state = state,
                        callbacks = callbacks
                    )
                }
            } else {
                item {
                    Text(
                        text = "暂不支持声音克隆",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 12.dp, bottom = 8.dp),
                        color = Color(0xFF98A2B3),
                        fontSize = 12.sp,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
            item {
                Column(modifier = Modifier.padding(top = 8.dp, bottom = 10.dp)) {
                    Text(
                        text = "AI 音色",
                        color = Color(0xFF344054),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = realtimeCallVoiceCatalogDescription(state.activeProvider),
                        modifier = Modifier.padding(top = 6.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
            }
            items(
                visibleRealtimeCallVoices(state.activeProvider, state.response?.voices.orEmpty()),
                key = { it.voice }
            ) { voice ->
                RealtimeCallVoiceRow(
                    voice = voice,
                    switching = state.switching,
                    playing = playingVoice == voice.voice,
                    onSelect = callbacks.onSelectVoice,
                    onPreview = {
                        val resourceId = v61VoicePreviewResource(voice.voice)
                        if (resourceId == 0) return@RealtimeCallVoiceRow
                        if (playingVoice == voice.voice) {
                            player?.release()
                            player = null
                            playingVoice = null
                        } else {
                            player?.release()
                            player = MediaPlayer.create(context, resourceId)?.also { preview ->
                                preview.setOnCompletionListener {
                                    preview.release()
                                    if (player === preview) {
                                        player = null
                                        playingVoice = null
                                    }
                                }
                                preview.start()
                            }
                            playingVoice = player?.let { voice.voice }
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun RealtimeCallVoiceRow(
    voice: RealtimeCallVoiceItem,
    switching: Boolean,
    playing: Boolean,
    onSelect: (String) -> Unit,
    onPreview: () -> Unit
) {
    val selected = voice.selected
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .clickable(enabled = !switching && !selected) { onSelect(voice.voice) },
        color = Color.White.copy(alpha = 0.82f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(
            1.dp,
            if (selected) Color(0x660A84FF) else Color.White.copy(alpha = 0.78f)
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 15.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = realtimeCallVoiceDisplayName(voice.voice, voice.displayName),
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = buildVoiceSubtitle(voice),
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                VoicePreviewButton(playing = playing, onClick = onPreview)
                VoiceStatusBadge(
                    text = when {
                        selected -> "当前"
                        switching -> "保存中"
                        else -> "选择"
                    },
                    selected = selected
                )
            }
        }
    }
}

@Composable
private fun VoiceStatusBadge(text: String, selected: Boolean) {
    Surface(
        color = if (selected) Color(0x1A007AFF) else Color(0xFFF2F4F7),
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            color = if (selected) Color(0xFF0A84FF) else Color(0xFF667085),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

internal fun buildVoiceSubtitle(voice: RealtimeCallVoiceItem): String = when (voice.voice) {
    DOUBAO_CLEAR_MALE_VOICE -> "Seeduplex clear male."
    else -> voice.description.ifBlank { voice.voice }
}

@Composable
private fun VoicePreviewButton(playing: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .size(32.dp)
            .clickable(onClick = onClick),
        color = Color(0xFFF2F4F7),
        shape = RoundedCornerShape(16.dp),
        elevation = 0.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = if (playing) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                contentDescription = if (playing) "停止预览" else "播放预览",
                tint = Color(0xFF344054),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

private const val DOUBAO_CLEAR_MALE_VOICE = "zh_male_xiaotian_jupiter_bigtts"

private val QWEN_CALL_VOICE_ORDER = listOf("Andre", "Ethan", "Katerina")
private val DOUBAO_CALL_VOICE_ORDER = listOf(DOUBAO_CLEAR_MALE_VOICE)

internal fun visibleRealtimeCallVoices(
    activeProvider: String,
    voices: List<RealtimeCallVoiceItem>
): List<RealtimeCallVoiceItem> {
    val orderedIds = if (activeProvider.equals("DOUBAO", ignoreCase = true)) {
        DOUBAO_CALL_VOICE_ORDER
    } else {
        QWEN_CALL_VOICE_ORDER
    }
    return voices
        .distinctBy { it.voice.lowercase() }
        .filter { voice -> orderedIds.any { it.equals(voice.voice, ignoreCase = true) } }
        .sortedBy { voice -> orderedIds.indexOfFirst { it.equals(voice.voice, ignoreCase = true) } }
}

internal fun realtimeCallVoiceDisplayName(voiceId: String, backendDisplayName: String): String = when (voiceId) {
    DOUBAO_CLEAR_MALE_VOICE -> "清朗男声"
    else -> backendDisplayName.ifBlank { voiceId }
}

internal fun realtimeCallVoiceCatalogDescription(activeProvider: String): String {
    val modelDisplayName = if (activeProvider.equals("DOUBAO", ignoreCase = true)) {
        AssistantCallModelDisplayNames.Doubao
    } else {
        AssistantCallModelDisplayNames.Qwen
    }
    return "当前语音大模型 $modelDisplayName 支持以下音色"
}

private fun v61VoicePreviewResource(voiceId: String): Int = when (voiceId) {
    DOUBAO_CLEAR_MALE_VOICE -> R.raw.doubao_clear_male
    "Andre" -> R.raw.andre
    "Ethan" -> R.raw.ethan
    "Katerina" -> R.raw.katerina
    else -> 0
}
