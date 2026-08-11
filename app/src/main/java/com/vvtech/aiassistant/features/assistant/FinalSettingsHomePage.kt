package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_settings.AssistantIdentityProfileStatus
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun FinalSettingsPageV3(
    developerToolsVisible: Boolean = false,
    onOpenDeveloperTools: () -> Unit,
    onOpenContactMethods: () -> Unit,
    onOpenMyIdentity: () -> Unit = {},
    myIdentityStatus: AssistantIdentityProfileStatus = AssistantIdentityProfileStatus.Empty,
    contactMethodCount: Int,
    realtimeProviderSummary: String,
    realtimeProviderLoading: Boolean,
    realtimeProviderError: String?,
    onOpenRealtimeProvider: () -> Unit,
    translationProviderSummary: String,
    translationProviderLoading: Boolean,
    translationProviderError: String?,
    onOpenTranslationProvider: () -> Unit,
    voiceCloneStatus: VoiceCloneStatusResponse?,
    voiceCloneLoading: Boolean,
    voiceCloneError: String?,
    onOpenVoiceClone: () -> Unit,
    realtimeCallVoiceSummary: String = "",
    realtimeCallVoiceLoading: Boolean = false,
    realtimeCallVoiceError: String? = null,
    onOpenRealtimeCallVoice: () -> Unit = {},
    selectedVoiceModelTitle: String = "千问 Omni-Flash-Realtime",
    onOpenVoiceModel: () -> Unit = {},
    onOpenTrustedCallee: () -> Unit = {},
    versionUpdateSummary: String = "",
    versionUpdateChecking: Boolean = false,
    onCheckVersionUpdate: () -> Unit = {},
    logUploadInProgress: Boolean = false,
    onUploadLogs: () -> Unit = {},
    onLogout: () -> Unit = {}
) {
    Column(modifier = Modifier.fillMaxSize()) {
        SettingsHomeTitleBar()
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 128.dp)
        ) {
            item {
                Spacer(modifier = Modifier.size(10.dp))
                FinalSettingCardV3(
                    title = "我的身份",
                    subtitle = "保存你在不同场合常用的身份信息",
                    value = "${myIdentityStatus.label} ›",
                    onClick = onOpenMyIdentity
                )
            }
            if (FinalRealtimeCallVoiceSettingsVisible) {
                item {
                    FinalSettingCardV3(
                        title = "语音大模型",
                        subtitle = "AI 通话模型、默认音色与声音克隆",
                        value = formatVoiceModelCardValue(
                            when {
                                realtimeProviderLoading -> "加载中"
                                !realtimeProviderError.isNullOrBlank() -> "加载失败"
                                else -> realtimeProviderSummary
                            }
                        ),
                        onClick = onOpenRealtimeProvider
                    )
                }
            }
            item {
                FinalSettingCardV3(
                    title = "实时翻译原音",
                    subtitle = "设置实时翻译通话的原声播放与混合比例",
                    value = "设置 ›",
                    onClick = onOpenTranslationProvider
                )
            }
            item {
                FinalSettingCardV3(
                    title = "可信来电MCP服务",
                    subtitle = "验证来电者的身份签名和证书",
                    value = "›",
                    onClick = onOpenTrustedCallee
                )
            }
            item {
                FinalSettingCardV3(
                    title = "版本更新",
                    subtitle = "检查可用更新",
                    value = if (versionUpdateChecking) "检测中" else versionUpdateSummary.ifBlank { "检查" },
                    onClick = onCheckVersionUpdate
                )
            }
            item {
                FinalSettingCardV3(
                    title = "日志上报",
                    subtitle = "压缩并上传对话日志，便于技术排查",
                    value = if (logUploadInProgress) "上传中" else "›",
                    onClick = onUploadLogs
                )
            }
            if (developerToolsVisible) {
                item {
                    FinalSettingCardV3(
                        title = "开发者功能",
                        subtitle = "调试日志、网络状态、SIP 诊断",
                        value = "›",
                        onClick = onOpenDeveloperTools
                    )
                }
            }
            item {
                SettingsLogoutAction(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp, bottom = 24.dp),
                    onClick = onLogout
                )
            }
        }
    }
}

@Composable
private fun SettingsHomeTitleBar() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 8.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Text(
            text = "设置",
            color = Color(0xFF111111),
            fontSize = 28.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

@Composable
private fun SettingsLogoutAction(
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "退出登录",
            color = Color(0xFFEF4444),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
