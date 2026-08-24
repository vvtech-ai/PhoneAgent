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
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
@Composable
internal fun SfRealSummaryCard(
    summary: SummaryData,
    confirmLabel: String,
    showAction: Boolean = true,
    onConfirm: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.90f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Surface(shape = RoundedCornerShape(999.dp), color = Color(0xFFEEF5FF)) {
                Text(
                    text = currentAppText("任务确认", "Task Confirmation"),
                    color = Color(0xFF1978F3),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                )
            }
            Text(
                text = summary.task,
                modifier = Modifier.padding(top = 8.dp),
                color = Color(0xFF16202C),
                fontSize = 15.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.Bold
            )
            SfSummaryLine(label = summary.targetLabel, value = summary.target)
            SfSummaryLine(label = summary.timeLabel, value = summary.time)
            SfSummaryLine(label = summary.extraLabel, value = summary.extra)
            summary.contactValue?.takeIf { it.isNotBlank() }?.let {
                SfSummaryLine(label = summary.contactLabel ?: currentAppText("联系方式", "Contact"), value = it)
            }
            summary.detailValue?.takeIf { it.isNotBlank() }?.let {
                SfSummaryLine(label = summary.detailLabel ?: currentAppText("补充信息", "Additional Info"), value = it)
            }
            if (showAction) {
                SfAiCtaBubble(
                    text = confirmLabel,
                    onClick = onConfirm
                )
            } else {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp),
                    shape = RoundedCornerShape(14.dp),
                    color = Color(0xFFF6FAFF),
                    border = BorderStroke(1.dp, Color(0xFFD8E8FF))
                ) {
                    Text(
                        text = currentAppText(
                            "等待语音确认：确认 / 开始 / 就这样",
                            "Waiting for voice confirmation: confirm / start / that's it"
                        ),
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                        color = Color(0xFF1978F3),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
internal fun SfSummaryLine(label: String, value: String) {
    if (value.isBlank()) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 7.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            color = Color(0xFF667085),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.width(72.dp)
        )
        Text(
            text = value,
            color = Color(0xFF344054),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
internal fun SfRealCallStatusCard(
    data: CallPageData,
    mode: CallUiMode,
    handoffInFlight: Boolean
) {
    val transcript = data.transcript.filter {
        it.role != TranscriptRole.Note && !sfLooksLikeCallResultSummaryLine(it.text)
    }
    val showCallState = !sfLooksLikeFinishedCallStatus(data.status)
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.94f),
        border = BorderStroke(1.dp, Color(0xFFE4ECF7))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(
                text = currentAppText("通话实时转写", "Live Call Transcript"),
                color = Color(0xFF0A84FF),
                fontSize = 12.sp,
                fontWeight = FontWeight.ExtraBold
            )
            if (showCallState) {
                Text(
                    text = currentAppText(
                        data.status,
                        sanitizeUserFacingNetworkText(data.status, VoiceLanguage.English)
                    ).ifBlank {
                        if (mode == CallUiMode.Human) {
                            currentAppText("人工接管中", "Human takeover in progress")
                        } else {
                            currentAppText("AI 通话中", "AI call in progress")
                        }
                    },
                    modifier = Modifier.padding(top = 5.dp),
                    color = Color(0xFF667085),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
                val modeText = when {
                    handoffInFlight -> currentAppText("正在切换接管状态", "Switching takeover state")
                    mode == CallUiMode.Human -> currentAppText("当前由人工处理", "Currently handled by a human")
                    else -> currentAppText("当前由 AI 处理", "Currently handled by AI")
                }
                Text(
                    text = modeText,
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF0A84FF),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            transcript.takeLast(6).forEach { line ->
                val role = when (line.role) {
                    TranscriptRole.Assistant -> "AI"
                    TranscriptRole.Remote -> currentAppText("对方", "Other Side")
                    TranscriptRole.Note -> currentAppText("状态", "Status")
                }
                Text(
                    text = "$role${currentAppText("：", ": ")}${
                        currentAppText(
                            line.text,
                            sanitizeUserFacingNetworkText(line.text, VoiceLanguage.English)
                        )
                    }",
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF1F2937),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
            if (transcript.isEmpty()) {
                Text(
                    text = currentAppText(
                        "等待实时对话记录...",
                        "Waiting for realtime conversation records..."
                    ),
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF667085),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
        }
    }
}

@Composable
internal fun SfBackendStateCard(
    state: Index9AssistantUiState,
    onSelectSelectionOption: ((SelectionSheetOption) -> Unit)?,
    onConfirmTask: (() -> Unit)?,
    onSubmitSceneSupplement: ((String) -> Unit)?
) {
    val hasBackendState = state.clarificationSteps.isNotEmpty() ||
        state.selectionSheet != null ||
        state.summary != null ||
        state.detailSupplement != null ||
        state.processingTurn ||
        !state.error.isNullOrBlank()
    if (!hasBackendState) return

    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.90f),
        border = BorderStroke(1.dp, Color(0x260A84FF))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = currentAppText("真实流程状态", "Live Flow Status"),
                color = Color(0xFF0A84FF),
                fontSize = 12.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = sanitizeUserFacingNetworkText(state.status),
                modifier = Modifier.padding(top = 6.dp),
                color = Color(0xFF111111),
                fontSize = 14.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.Bold
            )
            if (state.processingTurn) {
                Text(
                    text = currentAppText(
                        "后端正在处理当前轮对话...",
                        "The backend is processing the current turn..."
                    ),
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp
                )
            }
            state.error?.takeIf { it.isNotBlank() }?.let { error ->
                Text(
                    text = sanitizeUserFacingError(error),
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFFE14D46),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
            state.clarificationSteps.takeLast(2).forEach { step ->
                Text(
                    text = "${
                        if (step.role == VoiceRole.User) {
                            currentAppText("用户", "User")
                        } else {
                            "AI"
                        }
                    }${currentAppText("：", ": ")}${step.text}",
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF344054),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
            state.selectionSheet?.let { sheet ->
                Text(
                    text = sheet.title,
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color(0xFF111111),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = sheet.subtitle,
                    modifier = Modifier.padding(top = 4.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
                sheet.options.forEach { option ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                            .clickable(enabled = onSelectSelectionOption != null) {
                                onSelectSelectionOption?.invoke(option)
                            },
                        color = Color(0xFFF4F9FF),
                        shape = RoundedCornerShape(14.dp),
                        border = BorderStroke(1.dp, Color(0x260A84FF))
                    ) {
                        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                            Text(
                                text = option.title,
                                color = Color(0xFF111111),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = listOf(option.phone, option.meta).filter { it.isNotBlank() }.joinToString(" · "),
                                modifier = Modifier.padding(top = 4.dp),
                                color = Color(0xFF6E6E73),
                                fontSize = 12.sp,
                                lineHeight = 17.sp
                            )
                        }
                    }
                }
            }
            state.summary?.let { summary ->
                Text(
                    text = "${summary.taskLabel}${summary.task}",
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color(0xFF111111),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = "${summary.targetLabel}${summary.target} · ${summary.timeLabel}${summary.time}",
                    modifier = Modifier.padding(top = 4.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp)
                        .clickable(enabled = onConfirmTask != null) { onConfirmTask?.invoke() },
                    color = Color(0xFF0A84FF),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Text(
                        text = state.confirmLabel,
                        modifier = Modifier.padding(vertical = 11.dp),
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                }
            }
            state.detailSupplement?.let { supplement ->
                Text(
                    text = supplement.title,
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color(0xFF111111),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = supplement.intro,
                    modifier = Modifier.padding(top = 4.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
                if (onSubmitSceneSupplement != null) {
                    Text(
                        text = currentAppText(
                            "可在下方输入补充信息后继续发送。",
                            "Enter additional information below, then send again."
                        ),
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color(0xFF0A84FF),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

// Clickable version for pure voice mode
