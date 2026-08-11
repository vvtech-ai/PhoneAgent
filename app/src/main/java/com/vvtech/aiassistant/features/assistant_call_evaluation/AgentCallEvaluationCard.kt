package com.vvtech.aiassistant.features.assistant_call_evaluation

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Divider
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ThumbDown
import androidx.compose.material.icons.outlined.ThumbUp
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val EvaluationBlue = Color(0xFF0A84FF)
private val EvaluationText = Color(0xFF1F2937)
private val EvaluationLabel = Color(0xFF718096)

@Composable
internal fun AgentCallEvaluationCard(
    state: AgentCallEvaluationUiState,
    onRatingSelected: (AgentCallRating) -> Unit,
) {
    Surface(
        modifier = Modifier.width(198.dp),
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        border = BorderStroke(1.dp, Color(0xFFE8EDF2)),
        elevation = 2.dp,
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 11.dp)) {
            EvaluationValueRow("使用模型", state.modelName)
            EvaluationValueRow(
                "平均时延",
                state.latencyText,
                modifier = Modifier.padding(top = 6.dp),
            )
            Divider(
                modifier = Modifier.padding(top = 9.dp),
                color = Color(0xFFEEF2F7),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "评价",
                    color = EvaluationLabel,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                )
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.End,
                ) {
                    RatingButton(
                        icon = Icons.Outlined.ThumbUp,
                        description = "好评",
                        selected = state.rating == AgentCallRating.Good,
                        enabled = !state.saving,
                        onClick = { onRatingSelected(AgentCallRating.Good) },
                    )
                    RatingButton(
                        icon = Icons.Outlined.ThumbDown,
                        description = "差评",
                        selected = state.rating == AgentCallRating.Bad,
                        enabled = !state.saving,
                        onClick = { onRatingSelected(AgentCallRating.Bad) },
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }
            }
            state.message?.let {
                Text(
                    text = it,
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFFD92D20),
                    fontSize = 10.sp,
                )
            }
        }
    }
}

@Composable
private fun EvaluationValueRow(label: String, value: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = label,
            color = EvaluationLabel,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = value,
            modifier = Modifier.weight(1f),
            color = EvaluationText,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.End,
        )
    }
}

@Composable
private fun RatingButton(
    icon: ImageVector,
    description: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier
            .width(30.dp)
            .height(29.dp)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        shape = RoundedCornerShape(10.dp),
        color = if (selected) Color(0xFFE6F3FF) else Color(0xFFF8FAFD),
        border = BorderStroke(1.dp, if (selected) Color(0xFFA7D4FF) else Color(0xFFE8E8E9)),
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = description,
                modifier = Modifier.size(15.dp),
                tint = if (selected) EvaluationBlue else Color(0xFF344054),
            )
        }
    }
}
