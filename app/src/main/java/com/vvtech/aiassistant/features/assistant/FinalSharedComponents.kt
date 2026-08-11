package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Menu
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_ui.AssistantPauseGlyph
import com.vvtech.aiassistant.features.assistant_ui.AssistantVoiceWave
import kotlin.math.max

@Composable
internal fun PhoneFrameWithBackground(content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(Color.White, Color(0xFFF5F7FA), Color(0xFFEAF0F6)),
                        center = Offset(size.width / 2f, 0f),
                        radius = max(size.width, size.height)
                    )
                )
            },
        contentAlignment = Alignment.TopCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .widthIn(max = 430.dp)
        ) {
            content()
        }
    }
}

@Composable
internal fun FinalTopBar(
    title: String,
    onMenu: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp, bottom = 14.dp, start = 18.dp, end = 18.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            color = Color(0xFF121826),
            fontSize = 34.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 0.sp
        )
        Surface(
            modifier = Modifier
                .size(40.dp)
                .clickable(enabled = onMenu != null) { onMenu?.invoke() },
            color = Color.White.copy(alpha = 0.88f),
            shape = RoundedCornerShape(12.dp),
            border = BorderStroke(1.dp, Color(0xFFE8EDF4)),
            elevation = 0.dp
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(listOf(Color(0xFF34C759), Color(0xFF28A745))),
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Outlined.Menu,
                    contentDescription = "设置",
                    tint = Color(0xFF344256),
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
internal fun FinalBackBar(
    title: String,
    onBack: () -> Unit,
    onStop: (() -> Unit)? = null
) {
    FinalBackTitleBar(
        title = title,
        onBack = onBack,
        trailing = onStop?.let {
            {
                FinalStopButton(onClick = it)
            }
        }
    )
}

@Composable
internal fun FinalActionButton(
    label: String,
    modifier: Modifier = Modifier,
    tone: FinalButtonTone = FinalButtonTone.Primary,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val background = if (enabled) {
        when (tone) {
            FinalButtonTone.Primary -> Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB)))
            FinalButtonTone.Secondary -> Brush.verticalGradient(listOf(Color(0xFFF2F4F7), Color(0xFFE8ECF2)))
            FinalButtonTone.Success -> Brush.verticalGradient(listOf(Color(0xFF34C759), Color(0xFF28A745)))
            FinalButtonTone.Danger -> Brush.verticalGradient(listOf(Color(0xFFF36E68), Color(0xFFE14D46)))
        }
    } else {
        Brush.verticalGradient(listOf(Color(0xFFEEF2F7), Color(0xFFE8EDF5)))
    }
    val textColor = if (enabled) {
        when (tone) {
            FinalButtonTone.Secondary -> Color(0xFF344054)
            else -> Color.White
        }
    } else {
        Color(0xFF9CA7B5)
    }
    Surface(
        modifier = modifier
            .heightIn(min = 48.dp)
            .clickable(enabled = enabled, onClick = onClick),
        color = Color.Transparent,
        shape = RoundedCornerShape(18.dp),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(background, RoundedCornerShape(18.dp))
                .border(
                    width = if (enabled) 0.dp else 1.dp,
                    color = if (enabled) Color.Transparent else Color(0xFFDCE4EF),
                    shape = RoundedCornerShape(18.dp)
                )
                .padding(horizontal = 14.dp, vertical = 14.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = textColor,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

internal enum class FinalButtonTone { Primary, Secondary, Success, Danger }

@Composable
internal fun FinalMessageBubble(text: String, user: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = if (user) 0.dp else 10.dp),
        horizontalArrangement = if (user) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 290.dp),
            color = if (user) Color(0xFF0A84FF) else Color(0xFFF8FAFC),
            shape = RoundedCornerShape(
                topStart = 18.dp,
                topEnd = 18.dp,
                bottomStart = if (user) 18.dp else 8.dp,
                bottomEnd = if (user) 8.dp else 18.dp
            ),
            border = if (user) null else BorderStroke(1.dp, Color(0xFFE6ECF4)),
            elevation = 0.dp
        ) {
            Text(
                text = if (user) AnnotatedString(text) else parseInlineMarkdown(text),
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                color = if (user) Color.White else Color(0xFF243447),
                fontSize = 14.sp,
                lineHeight = 21.sp
            )
        }
    }
}

@Composable internal fun FinalThinkingBubble() = FinalAiLoadingBubbleV3(modifier = Modifier.padding(top = 10.dp))

@Composable
internal fun FinalVoiceRecognitionBubbleV3() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        horizontalArrangement = Arrangement.End
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 138.dp),
            color = Color.Transparent,
            shape = RoundedCornerShape(
                topStart = 22.dp,
                topEnd = 22.dp,
                bottomStart = 22.dp,
                bottomEnd = 10.dp
            ),
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier
                    .background(
                        brush = Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB))),
                        shape = RoundedCornerShape(
                            topStart = 22.dp,
                            topEnd = 22.dp,
                            bottomStart = 22.dp,
                            bottomEnd = 10.dp
                        )
                    )
                    .padding(horizontal = 10.dp, vertical = 10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .width(76.dp)
                        .height(22.dp),
                    contentAlignment = Alignment.Center
                ) {
                    FinalVoiceWave()
                }
            }
        }
    }
}

@Composable internal fun FinalVoiceWave() = AssistantVoiceWave()

@Composable internal fun FinalPauseGlyph() = AssistantPauseGlyph()

@Composable
internal fun FinalModeButton(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .shadow(
                elevation = if (selected) 6.dp else 0.dp,
                shape = RoundedCornerShape(14.dp),
                ambientColor = Color(0x0D000000),
                spotColor = Color(0x0D000000)
            )
            .clickable(onClick = onClick),
        color = if (selected) Color.White else Color.Transparent,
        shape = RoundedCornerShape(14.dp),
        elevation = 0.dp
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            color = if (selected) Color(0xFF111827) else Color(0xFF667085),
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
