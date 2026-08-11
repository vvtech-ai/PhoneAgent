package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames

internal enum class V88NetworkMode(val label: String) {
    Normal("正常"),
    Weak("弱网"),
    Offline("断网")
}

internal enum class V88PermissionKind(
    val title: String,
    val description: String
) {
    Microphone("麦克风权限", "用于语音输入和通话录音"),
    Storage("存储权限", "用于读取和保存文件附件"),
    Contacts("通讯录权限", "用于获取联系人信息"),
    Phone("电话权限", "用于拨打和管理通话")
}

internal data class V88VoiceModelOption(
    val id: String,
    val title: String,
    val subtitle: String,
    val enabled: Boolean = true
)

internal val V88VoiceModelOptions = listOf(
    V88VoiceModelOption(
        "QWEN_OMNI_PLUS",
        AssistantCallModelDisplayNames.Qwen,
        "阿里巴巴 · 全双工语音对话引擎"
    ),
    V88VoiceModelOption(
        "DOUBAO",
        AssistantCallModelDisplayNames.Doubao,
        "字节跳动 · 端到端双工语音模型"
    ),
    V88VoiceModelOption(
        "DOUBAO_SEEDUPLEX_3_0",
        "豆包实时语音 3.0",
        "字节跳动 · Seeduplex 全双工语音模型"
    ),
    V88VoiceModelOption("GPT", "GPT Realtime2.0", "GPT 实时语音模型", enabled = false)
)

internal fun defaultV88VoiceModelOption(): V88VoiceModelOption =
    V88VoiceModelOptions.firstOrNull { it.enabled } ?: V88VoiceModelOptions.first()

@Composable
internal fun V88HomeNotificationBanner(
    visible: Boolean,
    text: String,
    extra: String,
    success: Boolean = true,
    statusKind: FinalTaskStatusKind = if (success) FinalTaskStatusKind.Completed else FinalTaskStatusKind.Incomplete,
    onClick: () -> Unit = {},
    onClose: () -> Unit
) {
    val backgroundColor = when (statusKind) {
        FinalTaskStatusKind.Completed -> Color(0xFFEBF5FF)
        FinalTaskStatusKind.Incomplete -> Color(0xFFFFF7ED)
        FinalTaskStatusKind.Running -> Color(0xFFEFF6FF)
        FinalTaskStatusKind.ExecutionError -> Color(0xFFFEF2F2)
    }
    val dividerColor = when (statusKind) {
        FinalTaskStatusKind.Completed -> Color(0xFFB3D7FF)
        FinalTaskStatusKind.Incomplete -> Color(0xFFFFDDB3)
        FinalTaskStatusKind.Running -> Color(0xFFBFDBFE)
        FinalTaskStatusKind.ExecutionError -> Color(0xFFFECACA)
    }
    val iconColor = when (statusKind) {
        FinalTaskStatusKind.Completed -> Color(0xFF007AFF)
        FinalTaskStatusKind.Incomplete -> Color(0xFFF59E0B)
        FinalTaskStatusKind.Running -> Color(0xFF3B82F6)
        FinalTaskStatusKind.ExecutionError -> Color(0xFFEF4444)
    }
    val iconText = when (statusKind) {
        FinalTaskStatusKind.Completed -> "✓"
        FinalTaskStatusKind.Incomplete -> "!"
        FinalTaskStatusKind.Running -> "!"
        FinalTaskStatusKind.ExecutionError -> "!"
    }
    AnimatedVisibility(visible = visible, enter = fadeIn(), exit = fadeOut()) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(),
            color = backgroundColor,
            shape = RoundedCornerShape(0.dp),
            elevation = 0.dp
        ) {
            Column {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .clickable(
                                interactionSource = MutableInteractionSource(),
                                indication = null,
                                onClick = onClick
                            ),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(22.dp)
                                .background(iconColor, CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = iconText,
                                color = Color.White,
                                fontSize = 12.sp,
                                lineHeight = 14.sp,
                                fontWeight = FontWeight.ExtraBold,
                                textAlign = TextAlign.Center
                            )
                        }
                        Text(
                            text = text,
                            modifier = Modifier.weight(1f),
                            color = Color(0xFF333333),
                            fontSize = 13.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.Normal,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (extra.isNotBlank()) {
                            Text(
                                text = extra,
                                color = Color(0xFF007AFF),
                                fontSize = 11.sp,
                                lineHeight = 14.sp,
                                maxLines = 1
                            )
                        }
                    }
                    Text(
                        text = "×",
                        modifier = Modifier
                            .size(width = 22.dp, height = 24.dp)
                            .clickable(
                                interactionSource = MutableInteractionSource(),
                                indication = null,
                                onClick = onClose
                            ),
                        color = Color(0xFF999999),
                        fontSize = 18.sp,
                        lineHeight = 20.sp,
                        textAlign = TextAlign.Center
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(dividerColor)
                )
            }
        }
    }
}

@Composable
internal fun V88MenuButton(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .size(40.dp)
            .clickable(onClick = onClick),
        color = Color.White.copy(alpha = 0.86f),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.84f)),
        elevation = 0.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text("≡", color = Color(0xFF111111), fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
internal fun V88NetworkStatusLayer(
    mode: V88NetworkMode,
    blocking: Boolean,
    onRetry: () -> Unit,
    onDismissBlocker: () -> Unit
) {
    if (blocking) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0x99000000))
                .clickable(
                    interactionSource = MutableInteractionSource(),
                    indication = null,
                    onClick = onDismissBlocker
                ),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 34.dp),
                color = Color.White,
                shape = RoundedCornerShape(24.dp),
                elevation = 0.dp
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 22.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("无网络连接", color = Color(0xFF111111), fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                    Text(
                        text = "请检查网络设置后重试",
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center
                    )
                    FinalActionButton(
                        label = "重试",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 18.dp),
                        onClick = onRetry
                    )
                }
            }
        }
    }
}

@Composable
internal fun V88AttachmentSummaryCard(
    uploaded: Boolean,
    onUploadClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("参考资料", color = Color(0xFF111111), fontSize = 16.sp, fontWeight = FontWeight.ExtraBold)
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .clickable(onClick = onUploadClick),
                color = if (uploaded) Color(0xFFEFFBF3) else Color(0xFFF8FAFC),
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, if (uploaded) Color(0x5534C759) else Color(0xFFDDE5EF)),
                elevation = 0.dp
            ) {
                Text(
                    text = if (uploaded) "✓ 2 个文件已上传：会议章程.pdf、参会联络表.xlsx" else "点击添加参考资料",
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 16.dp),
                    color = if (uploaded) Color(0xFF1F8F45) else Color(0xFF667085),
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            if (uploaded) {
                Text(
                    text = "AI 已提炼话术要点：确认参会方式；说明会议时间地点；记录需改派代表或请假原因。",
                    modifier = Modifier.padding(top = 10.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
            }
        }
    }
}
