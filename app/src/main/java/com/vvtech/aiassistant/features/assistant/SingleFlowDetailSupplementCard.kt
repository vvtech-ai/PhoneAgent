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
@Composable
internal fun SfDetailSupplementCard(
    supplement: DetailSupplementPageData,
    savedContacts: List<PersonalInfoEntry>,
    selectedContact: EffectiveTaskContact?,
    manualContactMode: Boolean,
    contactInputError: String?,
    selectedQuestionIds: List<String>,
    onConfirmSavedContact: (PersonalInfoEntry) -> Unit,
    onManualContact: () -> Unit,
    onToggleQuestion: (DetailSupplementQuestionData) -> Unit,
    onConfirmDetails: () -> Unit,
    onSkipDetails: () -> Unit
) {
    val preferredContact = savedContacts.firstOrNull { it.isDefault } ?: savedContacts.firstOrNull()
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.90f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Surface(shape = RoundedCornerShape(999.dp), color = Color(0xFFFFF6E7)) {
                Text(
                    text = "需要补充",
                    color = Color(0xFFFF9F0A),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                )
            }
            Text(
                text = supplement.title,
                modifier = Modifier.padding(top = 8.dp),
                color = Color(0xFF16202C),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 21.sp
            )
            Text(
                text = supplement.intro,
                modifier = Modifier.padding(top = 5.dp),
                color = Color(0xFF667085),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
            if (selectedContact == null) {
                Text(
                    text = "先确认预订人信息",
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color(0xFF16202C),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                if (preferredContact != null && !manualContactMode) {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        shape = RoundedCornerShape(14.dp),
                        color = Color(0xFFF6FAFF),
                        border = BorderStroke(1.dp, Color(0xFFD8E8FF))
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "${preferredContact.name}${preferredContact.gender.sfDisplayLabel()}",
                                        color = Color(0xFF111827),
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = sfMaskPhone(preferredContact.phone),
                                        modifier = Modifier.padding(top = 4.dp),
                                        color = Color(0xFF667085),
                                        fontSize = 13.sp
                                    )
                                }
                                if (preferredContact.isDefault) {
                                    Surface(shape = RoundedCornerShape(999.dp), color = Color(0xFFEAF3FF)) {
                                        Text(
                                            text = "默认",
                                            color = Color(0xFF1978F3),
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                        )
                                    }
                                }
                            }
                            Row(
                                modifier = Modifier.padding(top = 12.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                SfSupplementActionButton(
                                    text = "确认使用此联系人",
                                    primary = true,
                                    modifier = Modifier.weight(1f),
                                    onClick = { onConfirmSavedContact(preferredContact) }
                                )
                                SfSupplementActionButton(
                                    text = "重新输入",
                                    primary = false,
                                    modifier = Modifier.weight(1f),
                                    onClick = onManualContact
                                )
                            }
                        }
                    }
                } else {
                    Text(
                        text = "请在下方输入联系人姓名和手机号",
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color(0xFF344054),
                        fontSize = 13.sp,
                        lineHeight = 18.sp
                    )
                    Text(
                        text = "姓名，188****0000",
                        modifier = Modifier.padding(top = 6.dp),
                        color = Color(0xFF007AFF),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                    contactInputError?.takeIf { it.isNotBlank() }?.let { error ->
                        Text(
                            text = error,
                            modifier = Modifier.padding(top = 6.dp),
                            color = Color(0xFFFF3B30),
                            fontSize = 12.sp,
                            lineHeight = 17.sp
                        )
                    }
                }
            } else {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    shape = RoundedCornerShape(14.dp),
                    color = Color(0xFFF7FFF9),
                    border = BorderStroke(1.dp, Color(0xFFCFEED8))
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "已确认",
                            color = Color(0xFF248A3D),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${selectedContact.sfDisplayName()}，${sfMaskPhone(selectedContact.phone)}",
                            modifier = Modifier.padding(start = 10.dp).weight(1f),
                            color = Color(0xFF16202C),
                            fontSize = 13.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
                Text(
                    text = "补充细节",
                    modifier = Modifier.padding(top = 12.dp),
                    color = Color(0xFF16202C),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                if (supplement.questions.isEmpty()) {
                    Text(
                        text = "当前没有额外细节，可直接跳过。",
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color(0xFF667085),
                        fontSize = 13.sp,
                        lineHeight = 18.sp
                    )
                } else {
                    Column(
                        modifier = Modifier.padding(top = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        supplement.questions.forEach { question ->
                            SfDetailQuestionOption(
                                question = question,
                                selected = selectedQuestionIds.contains(question.questionId),
                                onToggle = { onToggleQuestion(question) }
                            )
                        }
                    }
                }
                Column(
                    modifier = Modifier.padding(top = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    SfSupplementActionButton(
                        text = "确认补充",
                        primary = true,
                        enabled = selectedQuestionIds.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth(),
                        onClick = onConfirmDetails
                    )
                    SfSupplementActionButton(
                        text = "直接跳过",
                        primary = false,
                        modifier = Modifier.fillMaxWidth(),
                        onClick = onSkipDetails
                    )
                }
            }
        }
    }
}

@Composable
internal fun SfDetailQuestionOption(
    question: DetailSupplementQuestionData,
    selected: Boolean,
    onToggle: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle),
        shape = RoundedCornerShape(14.dp),
        color = if (selected) Color(0xFFEAF3FF) else Color(0xFFF7F9FC),
        border = BorderStroke(1.dp, if (selected) Color(0xFF9DCAFF) else Color(0xFFE3EAF3))
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(if (selected) Color(0xFF0A84FF) else Color.White)
                    .border(
                        width = 1.dp,
                        color = if (selected) Color(0xFF0A84FF) else Color(0xFFD0D5DD),
                        shape = RoundedCornerShape(6.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (selected) {
                    Text(
                        text = "✓",
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = question.prompt,
                modifier = Modifier.padding(start = 10.dp).weight(1f),
                color = Color(0xFF253247),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}

@Composable
internal fun SfSupplementActionButton(
    text: String,
    primary: Boolean,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(14.dp)
    val clickableModifier = if (enabled) modifier.clickable(onClick = onClick) else modifier
    Surface(
        modifier = clickableModifier,
        shape = shape,
        color = when {
            !enabled -> Color(0xFFE5E9F0)
            primary -> Color(0xFF0A84FF)
            else -> Color.White
        },
        border = BorderStroke(
            1.dp,
            when {
                !enabled -> Color(0xFFD5DAE2)
                primary -> Color(0xFF0A84FF)
                else -> Color(0xFFDDE4EF)
            }
        )
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            color = when {
                !enabled -> Color(0xFF98A2B3)
                primary -> Color.White
                else -> Color(0xFF16202C)
            },
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
