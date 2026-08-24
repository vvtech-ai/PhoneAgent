package com.vvtech.aiassistant.features.assistant_tasks

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun AssistantFinalResultPage(
    state: TaskFinalResultPageState,
    onBackHome: () -> Unit,
    onShare: () -> Unit,
    aiModelEnabled: Boolean = false,
    aiModelInFlight: Boolean = false,
    onAiModelCallContact: () -> Unit = {}
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFFFBFBFD), Color(0xFFEEF2F8))
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 52.dp)
                .padding(horizontal = 18.dp)
                .navigationBarsPadding()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 2.dp, end = 2.dp, top = 4.dp, bottom = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Surface(
                    modifier = Modifier
                        .size(40.dp)
                        .clickable(onClick = onBackHome),
                    color = Color.White.copy(alpha = 0.84f),
                    shape = RoundedCornerShape(999.dp),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.76f)),
                    elevation = 0.dp
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Outlined.ArrowBack,
                            contentDescription = "Back",
                            tint = Color(0xFF1B1D21),
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
                Text(
                    text = "Task Result",
                    color = Color(0xFF101114),
                    fontSize = 24.sp,
                    lineHeight = 28.sp,
                    fontWeight = FontWeight.ExtraBold,
                    maxLines = 1
                )
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentPadding = PaddingValues(bottom = 18.dp)
            ) {
                item {
                    AssistantFinalResultCard(
                        state = state,
                        onShare = onShare
                    )
                }
                item {
                    Spacer(modifier = Modifier.size(14.dp))
                    AssistantFinalAiModelContactButton(
                        enabled = aiModelEnabled && !aiModelInFlight,
                        loading = aiModelInFlight,
                        onClick = onAiModelCallContact
                    )
                }
            }
        }
    }
}

@Composable
private fun AssistantFinalAiModelContactButton(enabled: Boolean, loading: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick),
        color = if (enabled) Color(0xFF0A84FF) else Color(0xFFB8C0CC),
        shape = RoundedCornerShape(14.dp),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = if (loading) {
                    currentAppText("AI 建模中…", "AI Modeling...")
                } else {
                    currentAppText("🤖 AI 建模此联系人", "🤖 AI Model This Contact")
                },
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.ExtraBold
            )
        }
    }
}

@Composable
private fun AssistantFinalResultCard(
    state: TaskFinalResultPageState,
    onShare: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(26.dp),
                ambientColor = Color(0x10101828),
                spotColor = Color(0x10101828)
            ),
        color = Color.White.copy(alpha = 0.84f),
        shape = RoundedCornerShape(26.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.88f)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            AssistantFinalResultBadge(text = state.badge, success = state.success, partial = state.partial)
            Text(
                text = state.title,
                modifier = Modifier.padding(top = 14.dp),
                color = Color(0xFF101114),
                fontSize = 24.sp,
                lineHeight = 29.sp,
                fontWeight = FontWeight.ExtraBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = state.meta,
                modifier = Modifier.padding(top = 6.dp, bottom = 16.dp),
                color = Color(0xFF6F7582),
                fontSize = 14.sp,
                lineHeight = 19.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            state.rows.forEachIndexed { index, row ->
                AssistantFinalResultInfoRow(
                    label = row.label,
                    value = row.value,
                    showDivider = index < state.rows.lastIndex
                )
            }
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .clickable(onClick = onShare),
                color = Color.Transparent,
                shape = RoundedCornerShape(22.dp),
                elevation = 0.dp
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color(0xFF0A84FF), Color(0xFF0071EB))
                            ),
                            RoundedCornerShape(22.dp)
                        )
                        .padding(horizontal = 18.dp, vertical = 16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Share",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
        }
    }
}

@Composable
private fun AssistantFinalResultBadge(text: String, success: Boolean, partial: Boolean = false) {
    val textColor = when {
        partial -> Color(0xFFB45309)
        success -> Color(0xFF1C9F43)
        else -> Color(0xFFD92D20)
    }
    val backgroundColor = when {
        partial -> Color(0x1FF59E0B)
        success -> Color(0x1F34C759)
        else -> Color(0x1FFF3B30)
    }
    Surface(
        color = backgroundColor,
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
            color = textColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 1
        )
    }
}

@Composable
private fun AssistantFinalResultInfoRow(
    label: String,
    value: String,
    showDivider: Boolean
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = label,
                modifier = Modifier.weight(0.82f),
                color = Color(0xFF6F7582),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
            Text(
                text = value,
                modifier = Modifier.weight(1.18f),
                color = Color(0xFF111827),
                fontSize = 15.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.End,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
        }
        if (showDivider) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Color(0x12121926))
            )
        }
    }
}
