package com.vvtech.aiassistant.features.assistant_ui

import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.toComposePaint
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

private val BottomNavigationBackdropHeight = 154.dp
private val BottomNavigationBackdropBlurRadius = 17.dp

internal fun Modifier.assistantBottomNavigationBackdrop(
    visibilityProgress: Float
): Modifier = drawWithCache {
    val progress = visibilityProgress.coerceIn(0f, 1f)
    val backdropHeightPx = BottomNavigationBackdropHeight.toPx()
    val backdropTop = (size.height - backdropHeightPx).coerceAtLeast(0f)
    var platformBlurAvailable = false
    val blurPaint = android.graphics.Paint().apply {
        alpha = (255f * progress).roundToInt()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val blurRadiusPx = BottomNavigationBackdropBlurRadius.toPx()
            platformBlurAvailable = runCatching {
                applyPlatformBlurEffect(this, blurRadiusPx)
            }.isSuccess
        }
    }.toComposePaint()
    val wash = Brush.verticalGradient(
        colors = listOf(
            Color.Transparent,
            Color(0x14F8F9FC).copy(alpha = 0.08f * progress),
            Color(0x52F8F9FC).copy(alpha = 0.32f * progress)
        ),
        startY = backdropTop,
        endY = size.height
    )

    onDrawWithContent {
        val contentScope = this
        drawContent()
        if (progress <= 0f) return@onDrawWithContent
        clipRect(top = backdropTop) {
            if (platformBlurAvailable) {
                drawIntoCanvas { canvas ->
                    canvas.saveLayer(
                        Rect(0f, backdropTop, size.width, size.height),
                        blurPaint
                    )
                    contentScope.drawContent()
                    canvas.restore()
                }
            }
            drawRect(
                brush = wash,
                topLeft = Offset(0f, backdropTop),
                size = Size(size.width, backdropHeightPx)
            )
        }
    }
}

private fun applyPlatformBlurEffect(paint: android.graphics.Paint, radiusPx: Float) {
    val effect = RenderEffect.createBlurEffect(
        radiusPx,
        radiusPx,
        Shader.TileMode.CLAMP
    )
    android.graphics.Paint::class.java
        .getMethod("setRenderEffect", RenderEffect::class.java)
        .invoke(paint, effect)
}
