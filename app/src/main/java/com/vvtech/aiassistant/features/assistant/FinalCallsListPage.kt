package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
@Composable
internal fun FinalCallsPageV3(
    records: List<FinalCallRecord>,
    onOpenRecord: (FinalCallRecord) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalScreenTopBar(title = "通话")
        if (records.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 18.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "还没有通话记录",
                    color = Color(0xFF98A2B3),
                    fontSize = 14.sp
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 128.dp)
            ) {
                itemsIndexed(records) { index, record ->
                    val badgeLabel = record.callListBadgeLabel()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOpenRecord(record) }
                            .drawBehind {
                                drawLine(
                                    color = Color(0x1A3C3C43),
                                    start = Offset(0f, size.height),
                                    end = Offset(size.width, size.height),
                                    strokeWidth = 1.dp.toPx()
                                )
                            }
                            .padding(horizontal = 2.dp, vertical = 14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            if (badgeLabel != null) {
                                CallTypeBadge(label = badgeLabel)
                            }
                            Text(
                                text = record.callListTitle(),
                                modifier = Modifier.padding(top = if (badgeLabel == null) 0.dp else 6.dp),
                                color = Color(0xFF111111),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 0.sp
                            )
                            Text(
                                text = record.callListSummary(),
                                modifier = Modifier.padding(top = 5.dp),
                                color = Color(0xFF6E6E73),
                                fontSize = 13.sp,
                                lineHeight = 18.sp
                            )
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            if (badgeLabel == "Agent") {
                                CallOutcomeBadge(success = record.success)
                            }
                            Text(
                                text = finalCallTimeLabel(
                                    meta = record.meta,
                                    index = index,
                                    occurredAtMillis = record.occurredAtMillis
                                ),
                                modifier = Modifier.padding(top = if (badgeLabel == "Agent") 7.dp else 0.dp),
                                color = Color(0xFF6E6E73),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CallTypeBadge(label: String) {
    val translation = label == "实时翻译"
    Surface(
        color = if (translation) Color(0x1A7C4DFF) else Color(0x1A007AFF),
        shape = RoundedCornerShape(6.dp),
        elevation = 0.dp
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
            color = if (translation) Color(0xFF7C4DFF) else Color(0xFF007AFF),
            fontSize = 10.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

@Composable
private fun CallOutcomeBadge(success: Boolean) {
    Surface(
        color = if (success) Color(0x1A34C759) else Color(0x1AFF3B30),
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Text(
            text = if (success) "成功" else "失败",
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            color = if (success) Color(0xFF16A34A) else Color(0xFFFF3B30),
            fontSize = 11.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

private fun FinalCallRecord.callListBadgeLabel(): String? = when {
    status.contains("翻译") || title.startsWith("翻译通话") -> "实时翻译"
    callId.isNotBlank() || taskId.isNotBlank() || status.contains("AI") || meta.contains("Agent") -> "Agent"
    else -> null
}

private fun FinalCallRecord.callListTitle(): String = when {
    title.startsWith("翻译通话 ") -> title.removePrefix("翻译通话 ")
    title.startsWith("拨打 ") -> title.removePrefix("拨打 ")
    else -> title
}.ifBlank { phoneNumber.ifBlank { "未知号码" } }

private fun FinalCallRecord.callListSummary(): String {
    if (callListBadgeLabel() == "Agent") return meta.ifBlank { resultText }
    val displayTitle = callListTitle()
    val parts = buildList {
        if (phoneNumber.isNotBlank() && phoneNumber != displayTitle) add(phoneNumber)
        if (status.contains("普通通话")) add(if (title.startsWith("拨打 ")) "呼出" else "呼入")
        if (durationText.isNotBlank()) add(durationText)
    }
    return parts.joinToString(" · ").ifBlank { meta }
}
