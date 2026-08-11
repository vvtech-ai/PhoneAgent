package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun AgentCallDetailPage(
    record: FinalCallRecord?,
    onBack: () -> Unit,
    onDial: (FinalCallRecord) -> Unit,
    onReturnTask: (FinalCallRecord) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackBar(title = "通话转号", onBack = onBack)
        if (record == null) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "未找到通话记录", color = Color(0xFF98A2B3), fontSize = 14.sp)
            }
            return@Column
        }

        val dialogueTranscript = agentDialogueTranscriptLines(record.transcript)
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 28.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            item(key = "hero") {
                AgentCallDetailHero(record = record)
            }
            item(key = "time_chip") {
                AgentCallTimeChip(text = record.callTimeChipText())
            }
            if (dialogueTranscript.isEmpty()) {
                item(key = "empty_transcript") {
                    Text(
                        text = "暂无通话转写",
                        modifier = Modifier.padding(top = 22.dp),
                        color = Color(0xFF98A2B3),
                        fontSize = 13.sp
                    )
                }
            } else {
                itemsIndexed(dialogueTranscript) { index, line ->
                    AgentCallDetailTranscriptRow(
                        line = line,
                        showDivider = index < dialogueTranscript.lastIndex
                    )
                }
            }
        }

        AgentCallDetailFooter(
            record = record,
            onDial = onDial,
            onReturnTask = onReturnTask
        )
    }
}

@Composable
private fun AgentCallDetailHero(record: FinalCallRecord) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 2.dp, bottom = 18.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Text(
            text = "Agent 通话记录",
            color = Color(0xFF7B8493),
            fontSize = 14.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = record.title.ifBlank { "未记录被叫" },
            color = Color(0xFF111111),
            fontSize = 23.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = record.phoneNumber.ifBlank { "未记录号码" },
            color = Color(0xFF6E6E73),
            fontSize = 15.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun AgentCallTimeChip(text: String) {
    if (text.isBlank()) {
        Spacer(modifier = Modifier.height(2.dp))
        return
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp),
        horizontalArrangement = Arrangement.Center
    ) {
        Surface(
            color = Color(0xFFE8EBF2),
            shape = RoundedCornerShape(999.dp),
            elevation = 0.dp
        ) {
            Text(
                text = text,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 5.dp),
                color = Color(0xFF8B93A3),
                fontSize = 13.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.ExtraBold
            )
        }
    }
}

@Composable
private fun AgentCallDetailTranscriptRow(line: TranscriptLine, showDivider: Boolean) {
    AgentCallTranscriptBubble(
        line = line,
        modifier = Modifier
            .fillMaxWidth()
            .drawBehind {
                if (showDivider) {
                    drawLine(
                        color = Color(0xFFE5E7EB),
                        start = Offset(0f, size.height),
                        end = Offset(size.width, size.height),
                        strokeWidth = 1.dp.toPx()
                    )
                }
            }
            .padding(vertical = 10.dp),
        compact = true
    )
}

@Composable
private fun AgentCallDetailFooter(
    record: FinalCallRecord,
    onDial: (FinalCallRecord) -> Unit,
    onReturnTask: (FinalCallRecord) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color(0x00F8F9FC),
                        Color(0xEBF8F9FC),
                        Color(0xFAF8F9FC)
                    )
                )
            )
            .navigationBarsPadding()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally)
    ) {
        AgentCallDetailFooterButton(
            label = "拨号",
            modifier = Modifier.weight(1f),
            colors = listOf(Color(0xFF34C759), Color(0xFF28A745)),
            enabled = record.phoneNumber.isNotBlank(),
            onClick = { onDial(record) }
        )
        AgentCallDetailFooterButton(
            label = "返回任务",
            modifier = Modifier.weight(1f),
            colors = listOf(Color(0xFF0A84FF), Color(0xFF0071EB)),
            enabled = false,
            onClick = { onReturnTask(record) }
        )
    }
}

@Composable
private fun AgentCallDetailFooterButton(
    label: String,
    modifier: Modifier = Modifier,
    colors: List<Color>,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val background = if (enabled) {
        Brush.verticalGradient(colors)
    } else {
        Brush.verticalGradient(listOf(Color(0xFFE8EDF5), Color(0xFFDDE5F0)))
    }
    Surface(
        modifier = modifier
            .heightIn(min = 48.dp)
            .clickable(enabled = enabled, onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = Color.Transparent,
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(background, RoundedCornerShape(20.dp))
                .padding(horizontal = 12.dp, vertical = 13.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = Color.White,
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp
            )
        }
    }
}

private fun FinalCallRecord.callTimeChipText(): String {
    return startTimeText.ifBlank {
        dateText.ifBlank {
            meta.substringBefore("·").trim()
        }
    }.trim()
}
