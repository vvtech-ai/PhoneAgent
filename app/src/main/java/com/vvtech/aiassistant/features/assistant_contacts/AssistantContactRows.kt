package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalContactRecord
import com.vvtech.aiassistant.features.assistant.localizedFinalContactHint
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun AssistantContactsTopBar() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 10.dp, start = 22.dp, end = 22.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = currentAppText("联系人", "Contacts"),
                color = Color(0xFF111111),
                fontSize = 31.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                maxLines = 1
            )
        }
    }
}

@Composable
internal fun AssistantContactsEmptyState() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = currentAppText("暂无联系人", "No contacts yet"),
            color = Color(0xFF8E8E93),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
internal fun AssistantContactPlainRow(
    record: FinalContactRecord,
    showDivider: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .drawBehind {
                if (showDivider) {
                    drawLine(
                        color = Color(0x143C3C43),
                        start = Offset(0f, size.height),
                        end = Offset(size.width, size.height),
                        strokeWidth = 1.dp.toPx()
                    )
                }
            }
            .padding(horizontal = 10.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AssistantContactAvatar(initial = assistantContactInitial(record.name))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = record.name.ifBlank { currentAppText("联系人", "Contacts") },
                color = Color(0xFF111111),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = assistantContactSubtitle(record),
                modifier = Modifier.padding(top = 5.dp),
                color = Color(0xFF6E6E73),
                fontSize = 13.sp,
                lineHeight = 18.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
internal fun AssistantContactAvatar(
    initial: String,
    modifier: Modifier = Modifier.size(42.dp),
    fontSize: Int = 15
) {
    Box(
        modifier = modifier
            .shadow(
                elevation = if (fontSize > 15) 16.dp else 0.dp,
                shape = CircleShape,
                ambientColor = Color(0x384F7DFF),
                spotColor = Color(0x384F7DFF)
            )
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFF7AA8FF), Color(0xFF4F7DFF))
                ),
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = initial,
            color = Color.White,
            fontSize = fontSize.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 1
        )
    }
}

@Composable
internal fun AssistantContactProfileAction(
    label: String,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(20.dp)
    Surface(
        modifier = modifier
            .heightIn(min = 50.dp)
            .clickable(onClick = onClick),
        color = Color.Transparent,
        shape = shape,
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = if (primary) {
                        Brush.verticalGradient(listOf(Color(0xFF34C759), Color(0xFF28A745)))
                    } else {
                        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.84f), Color.White.copy(alpha = 0.84f)))
                    },
                    shape = shape
                )
                .border(
                    width = if (primary) 0.dp else 1.dp,
                    color = if (primary) Color.Transparent else Color(0x143C3C43),
                    shape = shape
                )
                .padding(horizontal = 16.dp, vertical = 14.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = if (primary) Color.White else Color(0xFF111111),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

internal fun assistantContactInitial(name: String): String =
    name.trim().take(1).ifBlank { "#" }

private fun assistantContactSubtitle(record: FinalContactRecord): String {
    val phone = record.phone.trim()
    val hint = localizedFinalContactHint(record.hint).trim()
    return when {
        phone.isBlank() && hint.isBlank() -> currentAppText("未设置号码", "No phone number")
        phone.isBlank() -> hint
        hint.isBlank() -> phone
        hint == phone -> phone
        else -> "$phone · $hint"
    }
}
