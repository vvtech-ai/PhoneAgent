package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun AgentCallTranscriptBubble(
    line: TranscriptLine,
    modifier: Modifier = Modifier,
    dark: Boolean = false,
    compact: Boolean = false
) {
    val assistant = line.role == TranscriptRole.Assistant
    val remote = line.role == TranscriptRole.Remote
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (assistant) Arrangement.End else Arrangement.Start
    ) {
        if (compact) {
            AgentCallTranscriptPlain(
                line = line,
                assistant = assistant,
                remote = remote,
                dark = dark
            )
        } else {
            AgentCallTranscriptCard(
                line = line,
                assistant = assistant,
                remote = remote,
                dark = dark
            )
        }
    }
}

@Composable
private fun AgentCallTranscriptPlain(
    line: TranscriptLine,
    assistant: Boolean,
    remote: Boolean,
    dark: Boolean
) {
    Column(
        modifier = Modifier.widthIn(max = 320.dp),
        horizontalAlignment = if (assistant) Alignment.End else Alignment.Start
    ) {
        AgentCallSpeakerChip(
            text = transcriptSpeakerLabel(line.role),
            assistant = assistant,
            remote = remote,
            dark = dark
        )
        Text(
            text = line.text,
            modifier = Modifier.padding(top = 7.dp),
            color = if (dark) Color.White.copy(alpha = 0.94f) else Color(0xFF171923),
            fontSize = 16.sp,
            lineHeight = 24.sp,
            textAlign = if (assistant) TextAlign.End else TextAlign.Start
        )
    }
}

@Composable
private fun AgentCallTranscriptCard(
    line: TranscriptLine,
    assistant: Boolean,
    remote: Boolean,
    dark: Boolean
) {
    Surface(
        modifier = Modifier.widthIn(max = 286.dp),
        shape = RoundedCornerShape(8.dp),
        color = when {
            dark && remote -> Color(0xFF123524)
            dark -> Color.White.copy(alpha = 0.10f)
            remote -> Color(0xFFDCFCE7)
            else -> Color.White
        },
        border = BorderStroke(
            1.dp,
            when {
                dark && remote -> Color(0x664ADE80)
                dark -> Color.White.copy(alpha = 0.10f)
                remote -> Color(0xFFBBF7D0)
                else -> Color(0xFFE2E8F0)
            }
        ),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalAlignment = if (assistant) Alignment.End else Alignment.Start
        ) {
            AgentCallSpeakerChip(
                text = transcriptSpeakerLabel(line.role),
                assistant = assistant,
                remote = remote,
                dark = dark
            )
            Text(
                text = line.text,
                modifier = Modifier.padding(top = 4.dp),
                color = if (dark) Color.White.copy(alpha = 0.94f) else Color(0xFF111827),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                textAlign = if (assistant) TextAlign.End else TextAlign.Start
            )
        }
    }
}

@Composable
private fun AgentCallSpeakerChip(
    text: String,
    assistant: Boolean,
    remote: Boolean,
    dark: Boolean
) {
    Surface(
        shape = RoundedCornerShape(7.dp),
        color = when {
            dark && assistant -> Color(0x333B82F6)
            dark && remote -> Color(0x334ADE80)
            assistant -> Color(0xFFE3F2FF)
            remote -> Color(0xFFDDFBEA)
            else -> Color(0xFFE8EDF5)
        },
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 4.dp),
            color = when {
                dark -> Color.White.copy(alpha = 0.82f)
                assistant -> Color(0xFF0A84FF)
                remote -> Color(0xFF20A75A)
                else -> Color(0xFF64748B)
            },
            fontSize = 13.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

private fun transcriptSpeakerLabel(role: TranscriptRole): String {
    return when (role) {
        TranscriptRole.Assistant -> "AI"
        TranscriptRole.Remote -> "对方"
        TranscriptRole.Note -> "记录"
    }
}

internal fun agentDialogueTranscriptLines(transcript: List<TranscriptLine>): List<TranscriptLine> {
    return transcript
        .filter { it.role == TranscriptRole.Assistant || it.role == TranscriptRole.Remote }
        .flatMap { line ->
            splitAgentTranscriptText(line.text).map { text -> line.copy(text = text) }
        }
}

private fun splitAgentTranscriptText(text: String): List<String> {
    val normalized = text.trim()
    if (normalized.isBlank()) return emptyList()
    val parts = normalized
        .split(Regex("(?<=[。！？!?；;])\\s*"))
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .ifEmpty { listOf(normalized) }
    val result = mutableListOf<String>()
    var buffer = ""
    parts.forEach { part ->
        if (part.length > AgentTranscriptMaxChunkLength) {
            if (buffer.isNotBlank()) {
                result += buffer
                buffer = ""
            }
            result += part.chunked(AgentTranscriptMaxChunkLength)
        } else if (buffer.length + part.length <= AgentTranscriptMaxChunkLength) {
            buffer += part
        } else {
            if (buffer.isNotBlank()) result += buffer
            buffer = part
        }
    }
    if (buffer.isNotBlank()) result += buffer
    return result
}

private const val AgentTranscriptMaxChunkLength = 52
