package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant_singleflow.SfCallControlButton as SingleFlowCallControlButton
import com.vvtech.aiassistant.features.assistant_singleflow.PvRestaurantOptionsCard as SingleFlowPvRestaurantOptionsCard
import com.vvtech.aiassistant.features.assistant_singleflow.SfRestaurantOptionsCard as SingleFlowRestaurantOptionsCard
import com.vvtech.aiassistant.features.assistant_singleflow.SfTaskReceiptOverlay as SingleFlowTaskReceiptOverlay

@Composable
internal fun PvRestaurantOptionsCard(
    options: List<SfRestaurantOption>,
    onSelect: (SfRestaurantOption) -> Unit
) {
    SingleFlowPvRestaurantOptionsCard(options = options, onSelect = onSelect)
}

@Composable
internal fun SfRestaurantOptionsCard(options: List<SfRestaurantOption>) {
    SingleFlowRestaurantOptionsCard(options = options)
}

@Composable
internal fun SfTaskReceiptOverlay(
    restaurantName: String,
    time: String,
    partySize: String,
    onDismiss: () -> Unit
) {
    SingleFlowTaskReceiptOverlay(
        restaurantName = restaurantName,
        time = time,
        partySize = partySize,
        onDismiss = onDismiss
    )
}

@Composable
internal fun SfCallControlButton(
    modifier: Modifier = Modifier,
    title: String,
    icon: String,
    active: Boolean = false,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    SingleFlowCallControlButton(
        modifier = modifier,
        title = title,
        icon = icon,
        active = active,
        danger = danger,
        onClick = onClick
    )
}

@Composable
internal fun SfWaveBars(
    color: Color,
    modifier: Modifier = Modifier
) {
    val transition = rememberInfiniteTransition(label = "voiceWave")
    val scaleA by transition.animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(680),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 0.95f,
        animationSpec = infiniteRepeatable(
            animation = tween(620, delayMillis = 100),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveB"
    )
    Row(
        modifier = modifier.height(24.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        SfWaveBar(color = color, alpha = 0.9f, scale = scaleA, height = 20.dp)
        SfWaveBar(color = color, alpha = 0.8f, scale = scaleB, height = 15.dp)
        SfWaveBar(color = color, alpha = 1f, scale = scaleA, height = 24.dp)
        SfWaveBar(color = color, alpha = 0.8f, scale = scaleB, height = 15.dp)
        SfWaveBar(color = color, alpha = 0.9f, scale = scaleA, height = 20.dp)
    }
}

@Composable
internal fun SfWaveBar(
    color: Color,
    alpha: Float,
    scale: Float,
    height: Dp
) {
    Box(
        modifier = Modifier
            .width(4.dp)
            .height(height)
            .alpha(alpha)
            .graphicsLayer(scaleY = scale)
            .clip(RoundedCornerShape(999.dp))
            .background(color)
    )
}
