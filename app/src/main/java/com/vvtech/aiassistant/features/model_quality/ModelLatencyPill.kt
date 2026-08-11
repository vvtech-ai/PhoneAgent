package com.vvtech.aiassistant.features.model_quality

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyStatus

internal data class ModelLatencyPillPresentation(
    val backgroundArgb: Int,
    val text: String,
    val accessibilityLabel: String
)

internal fun modelLatencyPillPresentation(
    reading: ModelLatencyReading
): ModelLatencyPillPresentation {
    if (reading.status in availableStatuses && reading.latencyMs == null) {
        return unavailablePresentation
    }
    return when (reading.status) {
        ModelLatencyStatus.UNKNOWN -> ModelLatencyPillPresentation(
            backgroundArgb = 0xFFD1D5DB.toInt(),
            text = "",
            accessibilityLabel = "模型延迟暂无数据"
        )
        ModelLatencyStatus.GOOD -> reading.availablePresentation(0xFF34C759.toInt(), "良好")
        ModelLatencyStatus.FAIR -> reading.availablePresentation(0xFFFFCC00.toInt(), "一般")
        ModelLatencyStatus.HIGH -> reading.availablePresentation(0xFFFF9500.toInt(), "较高")
        ModelLatencyStatus.UNAVAILABLE -> unavailablePresentation
    }
}

@Composable
internal fun ModelLatencyPill(
    reading: ModelLatencyReading,
    modifier: Modifier = Modifier
) {
    val presentation = modelLatencyPillPresentation(reading)
    Surface(
        modifier = modifier
            .height(16.dp)
            .widthIn(min = if (reading.status == ModelLatencyStatus.UNAVAILABLE) 44.dp else 38.dp)
            .semantics { contentDescription = presentation.accessibilityLabel },
        color = Color(presentation.backgroundArgb),
        shape = RoundedCornerShape(50),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier.padding(horizontal = 6.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = presentation.text,
                color = Color.White,
                fontSize = 9.sp,
                fontWeight = FontWeight.ExtraBold,
                maxLines = 1
            )
        }
    }
}

private fun ModelLatencyReading.availablePresentation(
    backgroundArgb: Int,
    qualityLabel: String
): ModelLatencyPillPresentation {
    val latency = requireNotNull(latencyMs) {
        "Available model latency status must include latencyMs"
    }
    return ModelLatencyPillPresentation(
        backgroundArgb = backgroundArgb,
        text = "${latency}ms",
        accessibilityLabel = "模型延迟${qualityLabel}，${latency}毫秒"
    )
}

private val availableStatuses = setOf(
    ModelLatencyStatus.GOOD,
    ModelLatencyStatus.FAIR,
    ModelLatencyStatus.HIGH
)

private val unavailablePresentation = ModelLatencyPillPresentation(
    backgroundArgb = 0xFFFF3B30.toInt(),
    text = "不可用",
    accessibilityLabel = "模型不可用"
)
