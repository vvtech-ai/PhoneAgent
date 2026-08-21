package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.delay

private val ThinkingBg = Color(0xFFF5F3FF)
private val ThinkingText = Color(0xFF6B5FCC)
private val ThinkingContent = Color(0xFF555555)
private val ToolBg = Color(0xFFF0F7FF)
private val ToolText = Color(0xFF3B82B0)
private val ToolPending = Color(0xFFB58A2A)

@Composable
fun AgentThinkingBlock(
    thinking: String?,
    toolCalls: List<ToolCallInfo>?,
    toolCards: List<ToolCardInfo> = emptyList(),
    modifier: Modifier = Modifier,
    streaming: Boolean = false,
    thinkingStartedAt: Long? = null,
    thinkingDurationMs: Long? = null,
    partialToolCalls: List<PartialToolCall> = emptyList()
) {
    val hasThinking = !thinking.isNullOrBlank() ||
        (streaming && thinkingDurationMs == null && thinkingStartedAt != null)
    val hasToolCards = toolCards.isNotEmpty()
    val hasToolCalls = !toolCalls.isNullOrEmpty() || partialToolCalls.isNotEmpty()
    if (!hasThinking && !hasToolCards && !hasToolCalls) return

    Column(modifier = modifier.fillMaxWidth().padding(bottom = 6.dp)) {
        if (hasThinking) {
            ThinkingSection(
                thinking = thinking,
                streaming = streaming,
                startedAt = thinkingStartedAt,
                durationMs = thinkingDurationMs
            )
        }
        if (hasToolCards) {
            if (hasThinking) Spacer(modifier = Modifier.height(4.dp))
            ToolCardList(toolCards)
        }
        if (hasToolCalls) {
            if (hasThinking || hasToolCards) Spacer(modifier = Modifier.height(4.dp))
            ToolCallsSection(
                toolCalls = toolCalls,
                partialToolCalls = partialToolCalls,
                streaming = streaming
            )
        }
    }
}

@Composable
private fun ThinkingSection(
    thinking: String?,
    streaming: Boolean,
    startedAt: Long?,
    durationMs: Long?
) {
    val inProgress = streaming && durationMs == null
    var expanded by remember(streaming) { mutableStateOf(inProgress) }
    var elapsedMs by remember { mutableStateOf(0L) }

    LaunchedEffect(inProgress, startedAt) {
        if (inProgress && startedAt != null) {
            while (durationMs == null) {
                elapsedMs = System.currentTimeMillis() - startedAt
                delay(100)
            }
        }
    }

    val titleText = when {
        durationMs != null -> currentAppText(
            "场景信息已整理 ${formatSeconds(durationMs)}",
            "Scene details ready ${formatSeconds(durationMs)}"
        )
        inProgress -> currentAppText(
            "正在整理场景信息 ${formatSeconds(elapsedMs)}",
            "Organizing scene details ${formatSeconds(elapsedMs)}"
        )
        else -> currentAppText("场景信息", "Scene Details")
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(ThinkingBg)
            .clickable { expanded = !expanded }
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            when {
                inProgress -> Box(
                    modifier = Modifier
                        .padding(end = 8.dp)
                        .size(7.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color(0xFF0A84FF))
                )
                durationMs != null -> ChakenAiBrandBadge(modifier = Modifier.padding(end = 8.dp))
            }
            Text(
                text = titleText,
                color = ThinkingText,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.width(1.dp).weight(1f))
            Icon(
                imageVector = if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = ThinkingText,
                modifier = Modifier.size(16.dp)
            )
        }
        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            if (!thinking.isNullOrBlank()) {
                Text(
                    text = thinking,
                    color = ThinkingContent,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun ToolCardList(toolCards: List<ToolCardInfo>) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        toolCards.forEach { card ->
            AgentToolCard(card)
        }
    }
}

@Composable
private fun AgentToolCard(card: ToolCardInfo) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(14.dp),
            color = Color.White,
            border = BorderStroke(1.dp, Color(0xFFE8EDF2)),
            elevation = 1.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(18.dp)
                            .clip(RoundedCornerShape(5.dp))
                            .background(Color(0xFFE8F0FC)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = toolIcon(card),
                            color = Color(0xFF2196F3),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(
                        text = card.methodLabel,
                        color = Color(0xFF2196F3),
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                card.body.takeIf { it.isNotBlank() }?.let { body ->
                    Text(
                        text = body,
                        modifier = Modifier
                            .padding(top = 6.dp)
                            .fillMaxWidth()
                            .background(Color(0xFFF8F9FB), RoundedCornerShape(6.dp))
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        color = Color(0xFF667085),
                        fontSize = 11.sp,
                        lineHeight = 16.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
                card.result.takeIf { it.isNotBlank() }?.let { result ->
                    Text(
                        text = "✓ $result",
                        modifier = Modifier.padding(top = 5.dp),
                        color = Color(0xFF2E7D32),
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun ToolCallsSection(
    toolCalls: List<ToolCallInfo>?,
    partialToolCalls: List<PartialToolCall>,
    streaming: Boolean
) {
    val showPartials = streaming && partialToolCalls.isNotEmpty()
    var expanded by remember(streaming) { mutableStateOf(streaming) }

    val titleText = if (showPartials) {
        val running = partialToolCalls.count { it.result == null }
        if (running > 0) {
            currentAppText("工具处理中... (${partialToolCalls.size})", "Tools running... (${partialToolCalls.size})")
        } else {
            currentAppText("工具结果 ${partialToolCalls.size} 条", "Tool results (${partialToolCalls.size})")
        }
    } else {
        currentAppText("工具结果 ${toolCalls?.size ?: 0} 条", "Tool results (${toolCalls?.size ?: 0})")
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(ToolBg)
            .clickable { expanded = !expanded }
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.Build,
                contentDescription = null,
                tint = ToolText,
                modifier = Modifier.size(13.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = titleText,
                color = ToolText,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.width(1.dp).weight(1f))
            Icon(
                imageVector = if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = ToolText,
                modifier = Modifier.size(16.dp)
            )
        }
        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            Column(modifier = Modifier.padding(top = 6.dp)) {
                if (showPartials) {
                    partialToolCalls.forEach { ptc -> PartialToolRow(ptc) }
                } else {
                    toolCalls?.forEach { call ->
                        Text(
                            text = "🔧 ${call.name}",
                            color = ToolText,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                        if (call.result.isNotBlank()) {
                            Text(
                                text = "  ✓ ${stringResource(R.string.tool_completed)}",
                                color = ThinkingContent,
                                fontSize = 11.sp,
                                modifier = Modifier.padding(bottom = 4.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PartialToolRow(ptc: PartialToolCall) {
    val running = ptc.result == null
    Text(
        text = if (running) "🔧 ${ptc.name} ⏳ ${currentAppText("进行中...", "Running...")}"
            else "🔧 ${ptc.name} ✓ ${formatSeconds(ptc.durationMs ?: 0)}",
        color = if (running) ToolPending else ToolText,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium
    )
}

private fun formatSeconds(ms: Long): String {
    if (ms <= 0) return "0.0s"
    val sec = ms / 1000.0
    return "%.1fs".format(sec)
}

private fun toolIcon(card: ToolCardInfo): String {
    return when (card.toolName) {
        "search" -> "S"
        "askUser" -> "A"
        "showOptions" -> "O"
        "makeCall" -> "C"
        "stageReport" -> "R"
        else -> card.methodLabel.firstOrNull()?.uppercaseChar()?.toString() ?: "T"
    }
}
