package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload

private val SheetTextPrimary = Color(0xFF111111)
private val SheetTextSecondary = Color(0xFF6B7280)
private val SheetBlue = Color(0xFF0A84FF)
private val SheetTagBg = Color(0xFFEEF3F9)
private val SheetTagText = Color(0xFF304355)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AgentOptionsSheet(
    options: OptionsPayload,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(listOf(Color(0xFFF7FBFF), Color(0xFFEDF5FF))),
                RoundedCornerShape(22.dp)
            )
            .border(1.dp, Color(0xFFDCEBFF), RoundedCornerShape(22.dp))
            .padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 16.dp)
    ) {
        Text(
            text = options.title,
            color = SheetTextPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(12.dp))
        // 候选项至多 5 个，用 Column + forEach 而非 LazyColumn，避免在父 verticalScroll 容器内
        // 触发 infinity-height 约束崩溃（IllegalStateException）
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.items.forEach { item ->
                OptionCard(item = item, onSelect = { onSelect(item.id) })
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OptionCard(
    item: OptionItem,
    onSelect: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        color = Color.White,
        shape = RoundedCornerShape(16.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFE8EDF3)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = item.label,
                color = SheetTextPrimary,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            if (!item.detail.isNullOrBlank()) {
                Text(
                    text = item.detail,
                    color = SheetTextSecondary,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            val metaParts = mutableListOf<String>()
            if (!item.address.isNullOrBlank()) metaParts += item.address
            if (item.distanceMeters != null) {
                metaParts += if (item.distanceMeters >= 1000) {
                    "%.1fkm".format(item.distanceMeters / 1000.0)
                } else {
                    "${item.distanceMeters}m"
                }
            }
            if (metaParts.isNotEmpty()) {
                Text(
                    text = metaParts.joinToString(" | "),
                    color = SheetTextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            if (!item.tags.isNullOrEmpty()) {
                FlowRow(
                    modifier = Modifier.padding(top = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    item.tags.forEach { tag ->
                        Text(
                            text = tag,
                            color = SheetTagText,
                            fontSize = 11.sp,
                            modifier = Modifier
                                .background(SheetTagBg, RoundedCornerShape(6.dp))
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }
                }
            }
        }
    }
}
