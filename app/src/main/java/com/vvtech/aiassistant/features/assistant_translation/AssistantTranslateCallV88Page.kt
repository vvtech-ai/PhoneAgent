package com.vvtech.aiassistant.features.assistant_translation

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.core.model.TranslationCallSubtitleItem
import com.vvtech.aiassistant.features.assistant.formatSeconds

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun AssistantTranslateCallV88Page(
    phoneNumber: String,
    seconds: Int,
    status: TranslationCallStatusResponse?,
    error: String?,
    audioChannelStatus: String?,
    muted: Boolean,
    speakerEnabled: Boolean,
    panelCollapsed: Boolean,
    onMuteToggle: () -> Unit,
    onSpeakerToggle: () -> Unit,
    onPanelToggle: () -> Unit,
    onHangup: () -> Unit
) {
    val statusBannerText = when {
        status?.passthroughActive == true ->
            status.passthroughReason?.ifBlank { "\u5df2\u68c0\u6d4b\u540c\u8bed\u79cd\uff0c\u5f53\u524d\u76f4\u8fde" }
                ?: "\u5df2\u68c0\u6d4b\u540c\u8bed\u79cd\uff0c\u5f53\u524d\u76f4\u8fde"
        !status?.statusMessage.isNullOrBlank() -> status?.statusMessage.orEmpty()
        !audioChannelStatus.isNullOrBlank() -> audioChannelStatus
        else -> "\u5b9e\u65f6\u7ffb\u8bd1\u4e2d \u00b7 \u81ea\u52a8\u8bc6\u522b\u8bed\u8a00"
    }
    val subtitleItems = status?.subtitleItems.orEmpty()
    val latestSubtitleItem = subtitleItems.lastOrNull()
    val subtitleListState = rememberLazyListState()

    LaunchedEffect(subtitleItems.size, latestSubtitleItem?.sourceText, latestSubtitleItem?.translatedText) {
        if (subtitleItems.isNotEmpty()) {
            subtitleListState.animateScrollToItem(subtitleItems.lastIndex)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A1A2E), Color(0xFF16213E))))
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, bottom = 124.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                item {
                    Surface(
                        modifier = Modifier.padding(top = 6.dp),
                        color = Color.White.copy(alpha = 0.10f),
                        shape = RoundedCornerShape(999.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = statusBannerText,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Box(
                        modifier = Modifier.padding(top = 16.dp).size(64.dp).background(
                            Brush.verticalGradient(listOf(Color(0xFF6C5CE7), Color(0xFF3B82F6))),
                            CircleShape
                        ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            phoneNumber.takeLast(4).take(1).ifBlank { "#" },
                            color = Color.White,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Black
                        )
                    }
                    Text(
                        phoneNumber.ifBlank { "\u672a\u77e5\u53f7\u7801" },
                        modifier = Modifier.padding(top = 10.dp),
                        color = Color.White,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Text(
                        text = "\u25cf \u7ffb\u8bd1\u901a\u8bdd \u00b7 ${formatSeconds(seconds)}",
                        modifier = Modifier.padding(top = 8.dp, bottom = 14.dp),
                        color = Color.White.copy(alpha = 0.62f),
                        fontSize = 13.sp
                    )
                }
                item {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color.White.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(22.dp),
                        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.10f)),
                        elevation = 0.dp
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(
                                "\u7ffb\u8bd1\u5bf9\u8bdd",
                                color = Color.White,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                            TranslateSubtitlePanel(subtitleItems, statusBannerText, error, subtitleListState)
                        }
                    }
                }
            }
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(start = 18.dp, end = 18.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically
            ) {
                AssistantTranslateCallControl(
                    label = "Mute",
                    icon = Icons.Outlined.Mic,
                    active = muted,
                    onClick = onMuteToggle
                )
                AssistantTranslateCallControl(
                    label = "Hang Up",
                    icon = Icons.Rounded.CallEnd,
                    danger = true,
                    onClick = onHangup
                )
                AssistantTranslateCallControl(
                    label = "Speaker",
                    icon = Icons.Outlined.VolumeUp,
                    active = speakerEnabled,
                    onClick = onSpeakerToggle
                )
            }
        }
    }
}

@Composable
private fun TranslateSubtitlePanel(
    subtitleItems: List<TranslationCallSubtitleItem>,
    statusBannerText: String,
    error: String?,
    subtitleListState: androidx.compose.foundation.lazy.LazyListState
) {
    if (subtitleItems.isEmpty()) {
        AssistantTranslateSection("\u901a\u8bdd\u72b6\u6001", statusBannerText, error.orEmpty())
    } else {
        LazyColumn(
            state = subtitleListState,
            modifier = Modifier.fillMaxWidth().height(260.dp),
            contentPadding = PaddingValues(top = 14.dp, bottom = 2.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(subtitleItems) { item ->
                val translatedText = item.translatedText.takeIf { it.isNotBlank() && it != item.sourceText }.orEmpty()
                AssistantTranslateSection(
                    translationSubtitleRoleLabelSafe(item.speakerRole),
                    item.sourceText.ifBlank { "--" },
                    translatedText,
                    modifier = Modifier
                )
            }
        }
    }
}

private fun translationSubtitleRoleLabelSafe(role: String?): String {
    return when (role?.lowercase().orEmpty()) {
        "caller" -> "\u4f60\u8bf4"
        "callee" -> "\u5bf9\u65b9\u8bf4"
        else -> role?.ifBlank { "--" } ?: "--"
    }
}

@Composable
private fun AssistantTranslateSection(
    label: String,
    original: String,
    translated: String,
    modifier: Modifier = Modifier.padding(top = 14.dp)
) {
    Column(modifier = modifier) {
        Text(label, color = Color.White.copy(alpha = 0.62f), fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Surface(
            modifier = Modifier.fillMaxWidth().padding(top = 7.dp),
            color = Color.White.copy(alpha = 0.10f),
            shape = RoundedCornerShape(16.dp),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(original, color = Color.White, fontSize = 14.sp, lineHeight = 20.sp)
                if (translated.isNotBlank()) {
                    Text(
                        translated,
                        modifier = Modifier.padding(top = 6.dp),
                        color = Color.White.copy(alpha = 0.56f),
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun AssistantTranslateCallControl(
    label: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    onClick: () -> Unit,
    danger: Boolean = false
) {
    Column(
        modifier = modifier.width(74.dp).clickable(onClick = onClick).padding(4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Surface(
            modifier = Modifier.size(56.dp).shadow(
                elevation = if (danger) 12.dp else 10.dp,
                shape = CircleShape,
                ambientColor = if (danger) Color(0x38FF3B30) else Color(0x1F000000),
                spotColor = if (danger) Color(0x38FF3B30) else Color(0x1F000000)
            ),
            color = when {
                danger -> Color(0xFFFF3B30)
                active -> Color(0xFF6C5CE7)
                else -> Color.White.copy(alpha = 0.84f)
            },
            shape = CircleShape,
            border = BorderStroke(1.dp, if (active || danger) Color.Transparent else Color.White.copy(alpha = 0.10f)),
            elevation = 0.dp
        ) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = label, tint = if (active || danger) Color.White else Color(0xFF111827), modifier = Modifier.size(23.dp))
            }
        }
        Text(
            text = label,
            modifier = Modifier.padding(top = 8.dp),
            color = if (active && !danger) Color(0xFFA78BFA) else Color.White.copy(alpha = 0.86f),
            fontSize = 12.sp,
            fontWeight = if (active || danger) FontWeight.ExtraBold else FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
