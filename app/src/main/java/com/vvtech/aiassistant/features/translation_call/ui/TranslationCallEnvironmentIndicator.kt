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
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun TranslationCallEnvironmentIndicator(
    environment: TranslationCallEnvironment?,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        EnvironmentItem(currentAppText("网络", "Network"), environment?.network?.state)
        EnvironmentItem("SIP", environment?.sip?.state)
        EnvironmentItem(currentAppText("模型", "Model"), environment?.model?.state)
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
    TranslationEnvironmentState.Pending -> currentAppText("检测中", "Checking")
    TranslationEnvironmentState.Available -> currentAppText("可用", "Available")
    TranslationEnvironmentState.Degraded -> currentAppText("较弱", "Degraded")
    TranslationEnvironmentState.Unavailable -> currentAppText("不可用", "Unavailable")
    TranslationEnvironmentState.NotApplicable -> currentAppText("不适用", "Not applicable")
}
