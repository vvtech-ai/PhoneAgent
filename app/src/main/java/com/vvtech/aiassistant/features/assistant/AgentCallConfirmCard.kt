package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.CallSpecPayload

private val ConfirmCardGreen = Color(0xFF2E7D32)
private val ConfirmCardBlue = Color(0xFF0A84FF)
private val ConfirmCardText = Color(0xFF111111)
private val ConfirmCardSubText = Color(0xFF5F6B7A)
private val ConfirmCardBorder = Color(0x3334C759)

@Composable
fun AgentCallConfirmCard(
    callSpec: CallSpecPayload,
    modifier: Modifier = Modifier,
    showActions: Boolean = false,
    onConfirm: () -> Unit = {},
    onEdit: () -> Unit = {}
) {
    Row(modifier = modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 320.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, ConfirmCardBorder),
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(listOf(Color(0xFFF2FBF4), Color(0xFFE0F7E5))))
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .height(7.dp)
                                .widthIn(min = 7.dp)
                                .background(ConfirmCardGreen, CircleShape)
                        )
                        Text(
                            text = stringResource(R.string.confirm_title),
                            color = ConfirmCardGreen,
                            fontSize = 14.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Surface(
                        color = Color(0x1F34C759),
                        shape = RoundedCornerShape(14.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = stringResource(R.string.confirm_executable),
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            color = Color(0xFF1E8E3E),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))
                ConfirmInfoRow(stringResource(R.string.agent_confirm_target), callSpec.targetName)
                ConfirmInfoRow(stringResource(R.string.agent_confirm_phone), callSpec.phoneNumber)
                ConfirmInfoRow(stringResource(R.string.agent_confirm_goal), callSpec.primaryGoal)
                visibleCallConfirmSummaryRows(callSpec.summaryLines).forEach { (label, value) ->
                    ConfirmInfoRow(label, value)
                }
                callSpec.negotiationRules.orEmpty().forEach { rule ->
                    ConfirmInfoRow(stringResource(R.string.agent_confirm_extra), rule)
                }
                callSpec.boundaries.orEmpty().forEach { boundary ->
                    ConfirmInfoRow(stringResource(R.string.agent_confirm_boundary), boundary)
                }

                if (showActions) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        ConfirmActionButton(
                            text = stringResource(R.string.agent_confirm_edit),
                            textColor = ConfirmCardSubText,
                            background = Color.White.copy(alpha = 0.78f),
                            modifier = Modifier.weight(1f),
                            onClick = onEdit
                        )
                        ConfirmActionButton(
                            text = stringResource(R.string.agent_confirm_call),
                            textColor = Color.White,
                            background = ConfirmCardBlue,
                            modifier = Modifier.weight(1f),
                            onClick = onConfirm
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ConfirmInfoRow(label: String, value: String) {
    val safeValue = value.trim()
    if (safeValue.isBlank()) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            color = ConfirmCardSubText,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = safeValue,
            modifier = Modifier
                .padding(start = 12.dp)
                .weight(1f),
            color = ConfirmCardText,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.End
        )
    }
}

@Composable
private fun ConfirmActionButton(
    text: String,
    textColor: Color,
    background: Color,
    modifier: Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .height(36.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(background)
            .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = textColor,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
