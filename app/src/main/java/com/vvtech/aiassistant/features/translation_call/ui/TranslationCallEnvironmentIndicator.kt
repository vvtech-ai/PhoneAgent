package com.vvtech.aiassistant.features.translation_call.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironment
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState

@Composable
internal fun TranslationCallEnvironmentIndicator(
    environment: TranslationCallEnvironment?,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        EnvironmentItem("网络", environment?.network?.state)
        EnvironmentItem("SIP", environment?.sip?.state)
        EnvironmentItem("模型", environment?.model?.state)
    }
}

@Composable
private fun EnvironmentItem(
    label: String,
    state: TranslationEnvironmentState?
) {
    val resolvedState = state ?: TranslationEnvironmentState.Pending
    Row(
        modifier = Modifier.semantics {
            contentDescription = "$label ${resolvedState.accessibilityText()}"
        },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.78f),
            fontSize = 10.sp
        )
        Box(
            modifier = Modifier
                .size(width = 16.dp, height = 4.dp)
                .background(
                    color = resolvedState.indicatorColor(),
                    shape = RoundedCornerShape(50)
                )
        )
    }
}

internal fun TranslationEnvironmentState.indicatorColor(): Color = when (this) {
    TranslationEnvironmentState.Pending -> Color.White.copy(alpha = 0.5f)
    TranslationEnvironmentState.Available -> Color(0xFF34C759)
    TranslationEnvironmentState.Degraded -> Color(0xFFFF9F0A)
    TranslationEnvironmentState.Unavailable -> Color(0xFFFF453A)
    TranslationEnvironmentState.NotApplicable -> Color.White.copy(alpha = 0.34f)
}

private fun TranslationEnvironmentState.accessibilityText(): String = when (this) {
    TranslationEnvironmentState.Pending -> "检测中"
    TranslationEnvironmentState.Available -> "可用"
    TranslationEnvironmentState.Degraded -> "较弱"
    TranslationEnvironmentState.Unavailable -> "不可用"
    TranslationEnvironmentState.NotApplicable -> "不适用"
}
