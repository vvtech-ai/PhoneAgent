package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

private val PureVoiceCallBlue = Color(0xFF007AFF)
private val PureVoiceCallGreen = Color(0xFF34C759)

@Composable
internal fun PureVoiceSummaryRow(
    label: String,
    value: String,
    valueColor: Color = Color(0xFF333333)
) {
    if (value.isBlank()) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            color = Color(0xFF666666),
            fontSize = 12.sp,
            lineHeight = 16.sp
        )
        Text(
            text = value,
            modifier = Modifier.padding(start = 12.dp).weight(1f),
            color = valueColor,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.End,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
internal fun PureVoiceCallCard(data: CallPageData) {
    val transcript = data.transcript.filter {
        it.role != TranscriptRole.Note && !pureVoiceLooksLikeCallResultSummaryLine(it.text)
    }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.White,
            border = BorderStroke(1.dp, Color(0xFFE4ECF7)),
            elevation = 1.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
                Text(
                    text = currentAppText("通话实时转写", "Live Call Transcript"),
                    color = PureVoiceCallBlue,
                    fontSize = 11.sp,
                    lineHeight = 15.sp,
                    fontWeight = FontWeight.Bold
                )
                if (transcript.isNotEmpty()) {
                    Column(
                        modifier = Modifier.padding(top = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        transcript.forEach { line ->
                            val speaker = when (line.role) {
                                TranscriptRole.Assistant -> "AI"
                                TranscriptRole.Remote -> currentAppText("对方", "Other Side")
                                TranscriptRole.Note -> currentAppText("记录", "Note")
                            }
                            Row(verticalAlignment = Alignment.Top) {
                                Text(
                                    text = "$speaker${currentAppText("：", ": ")}",
                                    color = when (line.role) {
                                        TranscriptRole.Assistant -> PureVoiceCallBlue
                                        TranscriptRole.Remote -> PureVoiceCallGreen
                                        TranscriptRole.Note -> Color(0xFF667085)
                                    },
                                    fontSize = 13.sp,
                                    lineHeight = 19.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = currentAppText(
                                        line.text,
                                        sanitizeUserFacingNetworkText(line.text, VoiceLanguage.English)
                                    ),
                                    modifier = Modifier.weight(1f),
                                    color = Color(0xFF1F2937),
                                    fontSize = 13.sp,
                                    lineHeight = 19.sp
                                )
                            }
                        }
                    }
                } else {
                    Text(
                        text = currentAppText(
                            "等待实时对话记录...",
                            "Waiting for realtime conversation records..."
                        ),
                        modifier = Modifier.padding(top = 10.dp),
                        color = Color(0xFF667085),
                        fontSize = 13.sp,
                        lineHeight = 19.sp
                    )
                }
            }
        }
    }
}

internal fun pureVoiceLooksLikeCallResultSummaryLine(text: String): Boolean {
    val trimmed = text.trim()
    return trimmed.startsWith("预订结果：") ||
        trimmed.startsWith("预订结果:") ||
        trimmed.startsWith("AI代打结果：") ||
        trimmed.startsWith("AI代打结果:")
}

internal fun pureVoiceHasVisibleCallDialogue(data: CallPageData): Boolean {
    return data.transcript.any {
        it.role != TranscriptRole.Note && !pureVoiceLooksLikeCallResultSummaryLine(it.text)
    }
}

@Composable
internal fun PureVoiceCallResultCard(sceneType: String?, summary: SummaryData?, data: CallPageData) {
    val plan = pureVoiceCallResultPresentation(sceneType, summary, data)
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, plan.style.borderColor)
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(plan.style.gradient))
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                PureVoiceCallResultHeader(plan)
                PureVoiceCallResultBody(plan)
            }
        }
    }
}
