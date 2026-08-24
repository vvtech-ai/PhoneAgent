package com.vvtech.aiassistant.features.assistant_model

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading
import com.vvtech.aiassistant.features.assistant.V88VoiceModelOption
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.model_quality.ModelLatencyPill
import kotlinx.coroutines.launch
@Composable
internal fun V88VoiceModelSheet(
    selectedId: String,
    models: List<V88VoiceModelOption>,
    onSelect: (String) -> Unit,
    onClose: () -> Unit,
    latencySource: AiCallModelLatencySource = PendingBackendAiCallModelLatencySource
) {
    val modelIds = models.map(V88VoiceModelOption::id)
    var latencyState by remember(modelIds) { mutableStateOf(AiCallModelLatencyState()) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(modelIds, latencySource) {
        if (modelIds.isNotEmpty()) {
            latencyState = latencyState.startRefresh()
            val results = runCatching {
                latencySource.refresh(modelIds)
            }.getOrDefault(emptyMap())
            latencyState = latencyState.completeRefresh(modelIds, results)
        }
    }
    val resolvedSelectedId = models
        .firstOrNull { it.id == selectedId }
        ?.id
        ?: models.firstOrNull { it.enabled }?.id.orEmpty()
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x73000000))
            .clickable(
                interactionSource = MutableInteractionSource(),
                indication = null,
                onClick = onClose
            ),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .navigationBarsPadding()
                .clickable(
                    interactionSource = MutableInteractionSource(),
                    indication = null
                ) {},
            color = Color.White,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 32.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 20.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = currentAppText("选择 AI 通话模型", "Choose AI Call Model"),
                        color = Color(0xFF1A1A2E),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Rounded.Refresh,
                            contentDescription = currentAppText("刷新模型延迟", "Refresh model latency"),
                            tint = if (latencyState.refreshing) {
                                Color(0xFFC7C7CC)
                            } else {
                                Color(0xFF0A84FF)
                            },
                            modifier = Modifier
                                .size(36.dp)
                                .clickable(enabled = !latencyState.refreshing) {
                                    latencyState = latencyState.startRefresh()
                                    scope.launch {
                                        val results = runCatching {
                                            latencySource.refresh(modelIds)
                                        }.getOrDefault(emptyMap())
                                        latencyState = latencyState.completeRefresh(modelIds, results)
                                    }
                                }
                                .padding(8.dp)
                        )
                        Text(
                            text = "×",
                            modifier = Modifier
                                .clickable(onClick = onClose)
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            color = Color(0xFF999999),
                            fontSize = 22.sp,
                            lineHeight = 22.sp
                        )
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    models.forEach { option ->
                        V88VoiceModelOptionRow(
                            option = option,
                            selected = option.id == resolvedSelectedId,
                            enabled = option.enabled,
                            latencyReading = latencyState.readingOf(option.id),
                            onClick = {
                                onSelect(option.id)
                            }
                        )
                    }
                }
                Text(
                    text = currentAppText(
                        "模型切换将在下一次通话生效",
                        "Model changes take effect on the next call"
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                    color = Color(0xFF8B8FA3),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}
@Composable
private fun V88VoiceModelOptionRow(
    option: V88VoiceModelOption,
    selected: Boolean,
    enabled: Boolean,
    latencyReading: ModelLatencyReading,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick),
        color = when {
            !enabled -> Color(0xFFF7F7F8)
            selected -> Color(0x0F2196F3)
            else -> Color.White
        },
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(
            width = 1.5.dp,
                color = when {
                    !enabled -> Color(0xFFE9E9EC)
                    selected -> Color(0xFF2196F3)
                    else -> Color(0xFFE2E8F0)
                }
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = option.title,
                        color = if (enabled) Color(0xFF1A1A2E) else Color(0xFF9B9BA1),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    ModelLatencyPill(reading = latencyReading)
                }
                Text(
                    text = option.subtitle,
                    color = if (enabled) Color(0xFF8B8FA3) else Color(0xFFAEAEB2),
                    fontSize = 12.sp,
                    lineHeight = 16.sp
                )
            }
            V88VoiceModelRadio(selected = selected, enabled = enabled)
        }
    }
}

@Composable
private fun V88VoiceModelRadio(selected: Boolean, enabled: Boolean = true) {
    Box(
        modifier = Modifier
            .size(20.dp)
            .border(
                width = 1.5.dp,
                color = when {
                    !enabled -> Color(0xFFE0E1E4)
                    selected -> Color(0xFF2196F3)
                    else -> Color(0xFF98A2B3)
                },
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (selected && enabled) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(Color(0xFF2196F3), CircleShape)
            )
        }
    }
}
