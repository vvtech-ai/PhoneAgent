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
import androidx.compose.material.RadioButton
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
@Composable
internal fun PureVoiceIdleStage(
    modifier: Modifier = Modifier,
    voiceLanguage: VoiceLanguage = VoiceLanguage.Chinese,
    onMicClick: () -> Unit
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                modifier = Modifier
                    .size(BtnSize)
                    .clickable(onClick = onMicClick),
                shape = CircleShape,
                color = VoiceBlue,
                elevation = 8.dp
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Rounded.KeyboardVoice,
                        contentDescription = "Mic",
                        tint = Color.White,
                        modifier = Modifier.size(MicIconSize)
                    )
                }
            }
        }
        Text(
            text = voiceLanguage.standbyText,
            color = DesignTokens.textSecondary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(bottom = 24.dp)
        )
    }
}

// ════════════════════════════════════════════════════════
//  ColorfulWaveBars — 9-bar colorful waveform for AI speaking
//  Mirrors the phone-wave from dist/index.html
// ════════════════════════════════════════════════════════

// Symmetric bar heights (dp), scaled from phone-wave [16,28,48,72,110,72,48,28,16]
private val WaveBarHeights = listOf(5, 8, 14, 22, 26, 22, 14, 8, 5)

// Colorful gradient: blue → cyan → green → orange
private val WaveBarColors = listOf(
    Color(0xFF007AFF), // blue
    Color(0xFF00A3FF), // light blue
    Color(0xFF00C7BE), // cyan
    Color(0xFF30D158), // green
    Color(0xFF34C759), // green (center)
    Color(0xFF30D158), // green
    Color(0xFF00C7BE), // cyan
    Color(0xFF00A3FF), // light blue
    Color(0xFF007AFF)  // blue
)

@Composable
internal fun ColorfulWaveBars(slow: Boolean = false) {
    val baseDuration = if (slow) 1200 else 620
    val transition = rememberInfiniteTransition(label = "colorWave")
    val scaleA by transition.animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(baseDuration),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cwA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 0.95f,
        animationSpec = infiniteRepeatable(
            animation = tween((baseDuration * 0.9).toInt(), delayMillis = 80),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cwB"
    )
    val scaleC by transition.animateFloat(
        initialValue = 0.5f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween((baseDuration * 1.1).toInt(), delayMillis = 160),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cwC"
    )
    val scales = listOf(scaleA, scaleB, scaleC, scaleA, scaleB, scaleA, scaleC, scaleB, scaleA)

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        WaveBarHeights.forEachIndexed { index, heightDp ->
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(heightDp.dp)
                    .graphicsLayer(scaleY = scales[index])
                    .clip(RoundedCornerShape(999.dp))
                    .background(WaveBarColors[index])
            )
        }
    }
}

// ════════════════════════════════════════════════════════
//  WhiteWaveBars — 5-bar white waveform for user speaking
//  Style matches SfWaveBars from SingleFlowNativeDemoScreen
// ════════════════════════════════════════════════════════

@Composable
internal fun WhiteWaveBars() {
    val transition = rememberInfiniteTransition(label = "whiteWave")
    val scaleA by transition.animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(680),
            repeatMode = RepeatMode.Reverse
        ),
        label = "wwA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 0.95f,
        animationSpec = infiniteRepeatable(
            animation = tween(620, delayMillis = 100),
            repeatMode = RepeatMode.Reverse
        ),
        label = "wwB"
    )
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        WaveBar(color = Color.White, alpha = 0.9f, scale = scaleA, height = 12.dp)
        WaveBar(color = Color.White, alpha = 0.8f, scale = scaleB, height = 9.dp)
        WaveBar(color = Color.White, alpha = 1f, scale = scaleA, height = 14.dp)
        WaveBar(color = Color.White, alpha = 0.8f, scale = scaleB, height = 9.dp)
        WaveBar(color = Color.White, alpha = 0.9f, scale = scaleA, height = 12.dp)
    }
}

@Composable
internal fun WaveBar(
    color: Color,
    alpha: Float,
    scale: Float,
    height: Dp
) {
    Box(
        modifier = Modifier
            .width(3.dp)
            .height(height)
            .alpha(alpha)
            .graphicsLayer(scaleY = scale)
            .clip(RoundedCornerShape(999.dp))
            .background(color)
    )
}

// ════════════════════════════════════════════════════════
//  ThreeDotsIndicator — animated 3-dot loading indicator
// ════════════════════════════════════════════════════════

@Composable
internal fun ThreeDotsIndicator() {
    val transition = rememberInfiniteTransition(label = "dots")
    val offsetA by transition.animateFloat(
        initialValue = 0f,
        targetValue = -6f,
        animationSpec = infiniteRepeatable(
            animation = tween(400),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dotA"
    )
    val offsetB by transition.animateFloat(
        initialValue = 0f,
        targetValue = -6f,
        animationSpec = infiniteRepeatable(
            animation = tween(400, delayMillis = 150),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dotB"
    )
    val offsetC by transition.animateFloat(
        initialValue = 0f,
        targetValue = -6f,
        animationSpec = infiniteRepeatable(
            animation = tween(400, delayMillis = 300),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dotC"
    )
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        listOf(offsetA, offsetB, offsetC).forEach { offset ->
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .graphicsLayer(translationY = offset)
                    .clip(CircleShape)
                    .background(Color.White)
            )
        }
    }
}

// ════════════════════════════════════════════════════════
//  InteractionModeSettingsPage — settings sub-page
// ════════════════════════════════════════════════════════

@Composable
internal fun InteractionModeSettingsPage(
    pureVoiceMode: Boolean,
    voiceLanguage: VoiceLanguage = VoiceLanguage.Chinese,
    onBack: () -> Unit,
    onSelect: (Boolean) -> Unit,
    onSelectLanguage: (VoiceLanguage) -> Unit = {}
) {
    StandardPage(scrollable = true) {
        BackNavigationBar(label = "返回", onBack = onBack)
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = Color.White,
            shape = RoundedCornerShape(20.dp),
            border = BorderStroke(1.dp, Color(0xFFEDF1F5)),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                Text(
                    text = "交互模式",
                    color = DesignTokens.textPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "选择与 AI 对话时的界面风格",
                    modifier = Modifier.padding(top = 4.dp),
                    color = DesignTokens.textSecondary,
                    fontSize = 13.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                // option: dialog mode
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = { onSelect(false) })
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = !pureVoiceMode,
                        onClick = { onSelect(false) }
                    )
                    Column(modifier = Modifier.padding(start = 8.dp)) {
                        Text(
                            text = "对话模式",
                            color = DesignTokens.textPrimary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = "显示对话气泡，支持语音和文字输入",
                            color = DesignTokens.textSecondary,
                            fontSize = 12.sp
                        )
                    }
                }
                // option: pure voice mode
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = { onSelect(true) })
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = pureVoiceMode,
                        onClick = { onSelect(true) }
                    )
                    Column(modifier = Modifier.padding(start = 8.dp)) {
                        Text(
                            text = "纯语音模式",
                            color = DesignTokens.textPrimary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = "大按钮交互，纯语音操作，简洁直观",
                            color = DesignTokens.textSecondary,
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = Color.White,
            shape = RoundedCornerShape(20.dp),
            border = BorderStroke(1.dp, Color(0xFFEDF1F5)),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                Text(
                    text = "语音语言",
                    color = DesignTokens.textPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "选择纯语音模式下 AI 与你沟通的语言",
                    modifier = Modifier.padding(top = 4.dp),
                    color = DesignTokens.textSecondary,
                    fontSize = 13.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                VoiceLanguage.values().forEach { language ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(onClick = { onSelectLanguage(language) })
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = voiceLanguage == language,
                            onClick = { onSelectLanguage(language) }
                        )
                        Column(modifier = Modifier.padding(start = 8.dp)) {
                            Text(
                                text = language.label,
                                color = DesignTokens.textPrimary,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = language.settingsValue,
                                color = DesignTokens.textSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
