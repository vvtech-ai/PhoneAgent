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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
@Composable
internal fun SfSelectionSheetCard(
    sheet: SelectionSheetData,
    onSelect: (SelectionSheetOption) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.90f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(
                text = sheet.title,
                color = Color(0xFF121A24),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = sheet.subtitle,
                modifier = Modifier.padding(top = 5.dp),
                color = Color(0xFF6E788B),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
            Spacer(modifier = Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                sheet.options.forEachIndexed { index, option ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(option) },
                        shape = RoundedCornerShape(14.dp),
                        color = Color(0xFFF8FBFF),
                        border = BorderStroke(1.dp, Color(0xFFE4ECF7))
                    ) {
                        Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp)) {
                            Surface(
                                modifier = Modifier.size(24.dp),
                                shape = CircleShape,
                                color = Color(0xFF007AFF)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Text(
                                        text = "${index + 1}",
                                        color = Color.White,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                            Column(modifier = Modifier.padding(start = 10.dp).weight(1f)) {
                                Text(
                                    text = option.title,
                                    color = Color(0xFF17202C),
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = listOf(option.phone, option.meta).filter { it.isNotBlank() }.joinToString(" · "),
                                    modifier = Modifier.padding(top = 4.dp),
                                    color = Color(0xFF6E788B),
                                    fontSize = 12.sp,
                                    lineHeight = 17.sp
                                )
                                Text(
                                    text = option.actionLabel,
                                    modifier = Modifier.padding(top = 6.dp),
                                    color = Color(0xFF007AFF),
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
}

@Composable
internal fun SfVoiceContactConfirmCard(contact: PersonalInfoEntry) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.92f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.95f))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(shape = RoundedCornerShape(999.dp), color = Color(0xFFEAF3FF)) {
                    Text(
                        text = stringResource(R.string.selection_waiting_confirm),
                        color = Color(0xFF1978F3),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp)
                    )
                }
                Text(
                    text = stringResource(R.string.selection_booker_info),
                    modifier = Modifier.padding(start = 8.dp),
                    color = Color(0xFF16202C),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp),
                shape = RoundedCornerShape(14.dp),
                color = Color(0xFFF6FAFF),
                border = BorderStroke(1.dp, Color(0xFFD8E8FF))
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "${contact.name}${contact.gender.sfLocalizedDisplayLabel()}",
                            color = Color(0xFF111827),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = sfMaskPhone(contact.phone),
                            modifier = Modifier.padding(top = 4.dp),
                            color = Color(0xFF667085),
                            fontSize = 13.sp
                        )
                    }
                    if (contact.isDefault) {
                        Surface(shape = RoundedCornerShape(999.dp), color = Color.White.copy(alpha = 0.82f)) {
                            Text(
                                text = stringResource(R.string.selection_default),
                                color = Color(0xFF1978F3),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }
            Text(
                text = stringResource(R.string.selection_voice_confirm_hint),
                modifier = Modifier.padding(top = 8.dp),
                color = Color(0xFF667085),
                fontSize = 12.sp,
                lineHeight = 17.sp
            )
        }
    }
}

@Composable
private fun PersonalInfoGender.sfLocalizedDisplayLabel(): String = when (this) {
    PersonalInfoGender.Mr -> stringResource(R.string.identity_gender_mr)
    PersonalInfoGender.Ms -> stringResource(R.string.identity_gender_ms)
}
