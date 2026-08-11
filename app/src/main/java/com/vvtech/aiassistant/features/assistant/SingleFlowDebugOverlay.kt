package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.Checkbox
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Send
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ════════════════════════════════════════════════════════
//  VoiceDebugOverlay — 右侧调试悬浮面板（仅纯语音模式）
//  关闭方式：将 ShowVoiceDebugOverlay 改为 false
// ════════════════════════════════════════════════════════

@Composable
internal fun VoiceDebugOverlay(
    modifier: Modifier = Modifier,
    threadItems: List<SfThreadItem>,
    clarificationSteps: List<ClarificationStep>,
    liveUserTranscript: String?,
    liveAssistantTranscript: String?,
    status: String
) {
    val listState = rememberLazyListState()
    val totalCount = clarificationSteps.size + threadItems.size +
        (if (!liveUserTranscript.isNullOrBlank()) 1 else 0) +
        (if (!liveAssistantTranscript.isNullOrBlank()) 1 else 0)

    LaunchedEffect(totalCount) {
        if (totalCount > 0) listState.animateScrollToItem(maxOf(0, totalCount - 1))
    }

    Surface(
        modifier = modifier
            .width(196.dp)
            .heightIn(max = 420.dp),
        shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
        color = Color(0xD4111318),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp)
        ) {
            // 状态栏
            Text(
                text = "● ${status.ifBlank { "待机" }}",
                color = Color(0xFF6EE299),
                fontSize = 10.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(bottom = 6.dp)
            )
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f, fill = false),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // 真实语音流程的对话历史（clarificationSteps 优先展示）
                if (clarificationSteps.isNotEmpty()) {
                    items(clarificationSteps) { step ->
                        val label = if (step.role == VoiceRole.User) "我" else "AI"
                        val color = if (step.role == VoiceRole.User) Color(0xFFAABBFF) else Color(0xFF88DDAA)
                        VoiceDebugBubble(label, step.text, color)
                    }
                } else {
                    // mock 流程 fallback
                    items(threadItems) { item ->
                        when (item) {
                            is SfThreadItem.UserText ->
                                VoiceDebugBubble("我", item.text, Color(0xFFAABBFF))
                            is SfThreadItem.UserWave ->
                                VoiceDebugBubble("我", "（语音输入中）", Color(0xFF8899DD))
                            is SfThreadItem.AiText ->
                                VoiceDebugBubble("AI", item.text, Color(0xFF88DDAA))
                            is SfThreadItem.AiThinking ->
                                VoiceDebugBubble("AI", "思考中…", Color(0xFF999999))
                            is SfThreadItem.Summary ->
                                VoiceDebugBubble("摘要", item.text, Color(0xFFFFD080))
                            is SfThreadItem.Options ->
                                VoiceDebugBubble("选项", "${item.options.size} 个", Color(0xFFFFAACC))
                            is SfThreadItem.AiCta ->
                                VoiceDebugBubble("确认", item.text, Color(0xFFFFBB66))
                        }
                    }
                }
                if (!liveUserTranscript.isNullOrBlank()) {
                    item {
                        VoiceDebugBubble("我▶", liveUserTranscript, Color(0x99AABBFF))
                    }
                }
                if (!liveAssistantTranscript.isNullOrBlank()) {
                    item {
                        VoiceDebugBubble("AI▶", liveAssistantTranscript, Color(0x9988DDAA))
                    }
                }
            }
        }
    }
}

@Composable
internal fun VoiceDebugBubble(label: String, text: String, color: Color) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            color = color.copy(alpha = 0.65f),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = text,
            color = color,
            fontSize = 11.sp,
            lineHeight = 15.sp,
            maxLines = 5,
            overflow = TextOverflow.Ellipsis
        )
    }
}
