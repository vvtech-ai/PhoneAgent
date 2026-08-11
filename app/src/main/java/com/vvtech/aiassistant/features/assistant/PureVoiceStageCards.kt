package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material.icons.rounded.KeyboardVoice
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
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.CallSpecPayload

@Composable
internal fun PureVoiceThreadStageIndicator(text: String, done: Boolean) {
    val transition = rememberInfiniteTransition(label = "pvThreadStageDot")
    val dotAlpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(900),
            repeatMode = RepeatMode.Reverse
        ),
        label = "threadStageDotAlpha"
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .alpha(if (done) 1f else dotAlpha)
                .clip(CircleShape)
                .background(if (done) VoiceGreen else Color(0xFF2196F3))
        )
        Text(
            text = text,
            color = Color(0xFF2196F3),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            lineHeight = 17.sp
        )
    }
}

@Composable
internal fun PureVoiceBubble(
    text: String,
    user: Boolean,
    streaming: Boolean,
    keyHint: Int,
    error: Boolean = false
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (user) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            modifier = Modifier.widthIn(max = if (user) 220.dp else 260.dp),
            shape = RoundedCornerShape(
                topStart = 18.dp,
                topEnd = 18.dp,
                bottomEnd = if (user) 4.dp else 18.dp,
                bottomStart = if (user) 18.dp else 4.dp
            ),
            color = when {
                user -> Color.Transparent
                error -> Color(0xFFFFF3F0)
                else -> Color.White
            },
            border = if (error) BorderStroke(1.dp, Color(0xFFFFD8D2)) else null,
            elevation = if (user) 0.dp else 1.dp
        ) {
            Box(
                modifier = Modifier
                    .background(
                        brush = if (user) {
                            Brush.linearGradient(listOf(Color(0xFF007AFF), Color(0xFF0066DD)))
                        } else {
                            Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                        }
                    )
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Text(
                    text = text + if (streaming && keyHint < 0) "..." else "",
                    color = when {
                        user -> Color.White
                        error -> Color(0xFFC4382B)
                        else -> Color(0xFF1A1A1A)
                    },
                    fontSize = 14.sp,
                    lineHeight = 22.sp,
                    fontWeight = if (error) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

@Composable
internal fun PureVoiceThinkingCard(
    title: String,
    steps: List<String>,
    processing: Boolean = true
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomEnd = 18.dp, bottomStart = 4.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, Color(0x2E007AFF))
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.verticalGradient(listOf(Color(0xFFF3F8FF), Color(0xFFEDF4FF))))
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (processing) {
                        PureVoiceThinkingStars()
                    } else {
                        ChakenAiBrandBadge(label = title.ifBlank { "Phone Agent" })
                    }
                }
                Text(
                    text = "AI 思考过程",
                    modifier = Modifier.padding(top = 5.dp),
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF50627D)
                )
                steps.filter { it.isNotBlank() }.forEach { step ->
                    Text(
                        text = "· $step",
                        modifier = Modifier.padding(top = 4.dp),
                        color = Color(0xFF677892),
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun PureVoiceThinkingStars(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "pureVoiceSparkleLoader")
    val progress by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = PureVoiceSparkleDurationMs, easing = LinearEasing)
        ),
        label = "pureVoiceSparkleProgress"
    )
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        PureVoiceSparkle(progress = progress, fontSizeSp = 11, delayMs = 0)
        PureVoiceSparkle(progress = progress, fontSizeSp = 8, delayMs = 180)
        PureVoiceSparkle(progress = progress, fontSizeSp = 7, delayMs = 360)
    }
}

@Composable
private fun PureVoiceSparkle(
    progress: Float,
    fontSizeSp: Int,
    delayMs: Int
) {
    val phase = pureVoiceSparklePhase(progress, delayMs)
    val alpha = pureVoiceSparkleAlpha(phase)
    val scale = pureVoiceSparkleScale(phase)
    val offsetY = pureVoiceSparkleOffsetY(phase)
    val color = pureVoiceSparkleColor(phase)
    Text(
        text = "✦",
        color = color.copy(alpha = alpha),
        fontSize = fontSizeSp.sp,
        lineHeight = fontSizeSp.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 0.sp,
        modifier = Modifier.graphicsLayer(
            scaleX = scale,
            scaleY = scale,
            translationY = offsetY
        )
    )
}

private const val PureVoiceSparkleDurationMs = 1350

private val PureVoiceSparkleYellow = Color(0xFFFFD84D)
private val PureVoiceSparkleGreen = Color(0xFF34C759)
private val PureVoiceSparkleBlue = Color(0xFF0A84FF)

private fun pureVoiceSparklePhase(progress: Float, delayMs: Int): Float {
    val delayed = progress - delayMs.toFloat() / PureVoiceSparkleDurationMs
    return ((delayed % 1f) + 1f) % 1f
}

private fun pureVoiceSparkleAlpha(phase: Float): Float = when {
    phase < 0.33f -> lerpFloat(0.24f, 0.9f, phase / 0.33f)
    phase < 0.66f -> lerpFloat(0.9f, 1f, (phase - 0.33f) / 0.33f)
    else -> lerpFloat(1f, 0.24f, (phase - 0.66f) / 0.34f)
}

private fun pureVoiceSparkleScale(phase: Float): Float = when {
    phase < 0.33f -> lerpFloat(0.88f, 1.02f, phase / 0.33f)
    phase < 0.66f -> lerpFloat(1.02f, 1.08f, (phase - 0.33f) / 0.33f)
    else -> lerpFloat(1.08f, 0.88f, (phase - 0.66f) / 0.34f)
}

private fun pureVoiceSparkleOffsetY(phase: Float): Float = when {
    phase < 0.25f -> lerpFloat(0f, -3.6f, phase / 0.25f)
    phase < 0.5f -> lerpFloat(-3.6f, 0f, (phase - 0.25f) / 0.25f)
    phase < 0.75f -> lerpFloat(0f, 1.2f, (phase - 0.5f) / 0.25f)
    else -> lerpFloat(1.2f, 0f, (phase - 0.75f) / 0.25f)
}

private fun pureVoiceSparkleColor(phase: Float): Color = when {
    phase < 0.33f -> lerpColor(PureVoiceSparkleYellow, PureVoiceSparkleGreen, phase / 0.33f)
    phase < 0.66f -> lerpColor(PureVoiceSparkleGreen, PureVoiceSparkleBlue, (phase - 0.33f) / 0.33f)
    else -> lerpColor(PureVoiceSparkleBlue, PureVoiceSparkleYellow, (phase - 0.66f) / 0.34f)
}

private fun lerpFloat(start: Float, end: Float, fraction: Float): Float =
    start + (end - start) * fraction.coerceIn(0f, 1f)

private fun lerpColor(start: Color, end: Color, fraction: Float): Color {
    val t = fraction.coerceIn(0f, 1f)
    return Color(
        red = lerpFloat(start.red, end.red, t),
        green = lerpFloat(start.green, end.green, t),
        blue = lerpFloat(start.blue, end.blue, t),
        alpha = lerpFloat(start.alpha, end.alpha, t)
    )
}

@Composable
internal fun PureVoicePrethinkCard(label: String, body: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(12.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, Color(0xFFFFE0B2))
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(listOf(Color(0xFFFFF8E1), Color(0xFFFFF3E0))))
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Text(
                    text = label,
                    color = Color(0xFFE65100),
                    fontSize = 11.sp,
                    lineHeight = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = body,
                    modifier = Modifier.padding(top = 4.dp),
                    color = Color(0xFFE65100),
                    fontSize = 12.sp,
                    lineHeight = 19.sp
                )
            }
        }
    }
}

@Composable
internal fun PureVoiceIntentCard(title: String, items: List<String>) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(14.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, Color(0x2E34C759))
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(listOf(Color(0xFFEDFAF0), Color(0xFFDAFAE2))))
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Text(
                    text = title,
                    color = Color(0xFF2E7D32),
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                items.filter { it.isNotBlank() }.forEach { item ->
                    Row(
                        modifier = Modifier.padding(top = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(4.dp)
                                .clip(CircleShape)
                                .background(VoiceGreen)
                        )
                        Text(
                            text = item,
                            color = Color(0xFF333333),
                            fontSize = 12.sp,
                            lineHeight = 17.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceInfoRetrievalStage(
    sceneType: String?,
    firstUserText: String,
    selectionSheet: SelectionSheetData?,
    summary: SummaryData?,
    detailSupplement: DetailSupplementPageData?
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PureVoiceThreadStageIndicator(
            text = "阶段2 · 信息检索 · 可用工具: [search, get_detail, compare]",
            done = false
        )
        PureVoiceThinkingCard(
            title = "Phone Agent",
            steps = listOf(
                "进入需求确认子流程",
                "识别为候选选择任务",
                "召回候选结果并按相关性排序"
            )
        )
        PureVoiceToolCard(
            icon = "S",
            name = "Action: search()",
            body = "category: \"${selectionSheet?.targetLabel ?: pureVoiceResolvedTaskScene(sceneType, summary, detailSupplement) ?: "任务检索"}\"\nquery: \"${pureVoiceSearchQuery(firstUserText, summary, detailSupplement)}\"",
            result = selectionSheet?.let { "Observe: 返回 ${it.options.size} 个候选" }
                ?: "Observe: 已返回候选结果"
        )
    }
}

@Composable
internal fun PureVoiceCallResultPendingTip(text: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        Surface(
            modifier = Modifier.widthIn(max = 220.dp),
            shape = RoundedCornerShape(18.dp),
            color = Color(0xFFFFF8E6),
            border = BorderStroke(1.dp, Color(0x33C99700))
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                val transition = rememberInfiniteTransition(label = "callResultPendingDot")
                val dotAlpha by transition.animateFloat(
                    initialValue = 0.45f,
                    targetValue = 1f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(850),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "callResultPendingDotAlpha"
                )
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .alpha(dotAlpha)
                        .clip(CircleShape)
                        .background(Color(0xFFC99700))
                )
                Text(
                    text = text,
                    color = Color(0xFF8A6D1D),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
internal fun PureVoiceToolCard(icon: String, name: String, body: String, result: String?) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(14.dp),
            color = Color.White,
            border = BorderStroke(1.dp, Color(0xFFE8EDF2)),
            elevation = 1.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(
                        modifier = Modifier
                            .size(18.dp)
                            .clip(RoundedCornerShape(5.dp))
                            .background(Color(0xFFE8F0FC)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = icon,
                            color = Color(0xFF2196F3),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(
                        text = name,
                        color = VoiceBlue,
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                body.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = it,
                        modifier = Modifier
                            .padding(top = 6.dp)
                            .fillMaxWidth()
                            .background(Color(0xFFF8F9FB), RoundedCornerShape(6.dp))
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        color = Color(0xFF667085),
                        fontSize = 11.sp,
                        lineHeight = 16.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
                result?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = "✓ $it",
                        modifier = Modifier.padding(top = 5.dp),
                        color = VoiceGreen,
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}
