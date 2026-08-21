package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_settings.AssistantIdentityProfileStatus
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun FinalSettingsPageV3(
    developerToolsVisible: Boolean = false,
    onOpenDeveloperTools: () -> Unit,
    onOpenContactMethods: () -> Unit,
    appLanguage: AppLanguage = AppLanguage.English,
    onAppLanguageChange: (AppLanguage) -> Unit = {},
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
    var languageSheetVisible by rememberSaveable { mutableStateOf(false) }
    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            SettingsHomeTitleBar()
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 128.dp)
            ) {
                item {
                    Spacer(modifier = Modifier.size(10.dp))
                    FinalSettingCardV3(
                        title = stringResource(R.string.settings_caller_profile_title),
                        subtitle = stringResource(R.string.settings_caller_profile_description),
                        value = "${settingsIdentityStatusLabel(myIdentityStatus)} ›",
                        onClick = onOpenMyIdentity
                    )
                }
                if (FinalRealtimeCallVoiceSettingsVisible) {
                    item {
                        FinalSettingCardV3(
                            title = stringResource(R.string.settings_call_models_voices_title),
                            subtitle = stringResource(R.string.settings_call_models_voices_description),
                            value = formatVoiceModelCardValue(
                                when {
                                    realtimeProviderLoading -> stringResource(R.string.settings_status_loading)
                                    !realtimeProviderError.isNullOrBlank() ->
                                        stringResource(R.string.settings_status_failed_to_load)
                                    else -> realtimeProviderSummary
                                }
                            ),
                            onClick = onOpenRealtimeProvider
                        )
                    }
                }
                item {
                    FinalSettingCardV3(
                        title = stringResource(R.string.settings_live_translation_original_audio_title),
                        subtitle = stringResource(R.string.settings_live_translation_original_audio_description),
                        value = "${stringResource(R.string.settings_value_settings)} ›",
                        onClick = onOpenTranslationProvider
                    )
                }
                item {
                    FinalSettingCardV3(
                        title = stringResource(R.string.settings_trusted_call_mcp_title),
                        subtitle = stringResource(R.string.settings_trusted_call_mcp_description),
                        value = "›",
                        onClick = onOpenTrustedCallee
                    )
                }
                item {
                    AppLanguageSettingCard(
                        appLanguage = appLanguage,
                        onClick = { languageSheetVisible = true }
                    )
                }
                item {
                    FinalSettingCardV3(
                        title = stringResource(R.string.settings_software_update_title),
                        subtitle = stringResource(R.string.settings_software_update_description),
                        value = formatVoiceModelCardValue(
                            when {
                                versionUpdateChecking -> stringResource(R.string.settings_status_checking)
                                versionUpdateSummary.isBlank() -> stringResource(R.string.settings_action_check)
                                else -> versionUpdateSummary
                            }
                        ),
                        onClick = onCheckVersionUpdate
                    )
                }
                item {
                    FinalSettingCardV3(
                        title = stringResource(R.string.settings_log_upload_title),
                        subtitle = stringResource(R.string.settings_log_upload_description),
                        value = if (logUploadInProgress) {
                            stringResource(R.string.settings_status_uploading)
                        } else {
                            "›"
                        },
                        onClick = onUploadLogs
                    )
                }
                if (developerToolsVisible) {
                    item {
                        FinalSettingCardV3(
                            title = stringResource(R.string.settings_developer_features_title),
                            subtitle = stringResource(R.string.settings_developer_features_description),
                            value = "›",
                            onClick = onOpenDeveloperTools
                        )
                    }
                }
                item {
                    SettingsLogoutAction(
                        text = stringResource(R.string.settings_action_log_out),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 14.dp, bottom = 24.dp),
                        onClick = onLogout
                    )
                }
            }
        }
        if (languageSheetVisible) {
            AppLanguageSheet(
                appLanguage = appLanguage,
                onDismiss = { languageSheetVisible = false },
                onSelect = { selected ->
                    onAppLanguageChange(selected)
                    languageSheetVisible = false
                }
            )
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
            text = stringResource(R.string.settings_title),
            color = Color(0xFF111111),
            fontSize = 28.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

@Composable
private fun SettingsLogoutAction(
    text: String,
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
            text = text,
            color = Color(0xFFEF4444),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun AppLanguageSettingCard(
    appLanguage: AppLanguage,
    onClick: () -> Unit
) {
    FinalSettingCardV3(
        title = stringResource(R.string.settings_app_language_title),
        subtitle = stringResource(R.string.settings_app_language_description),
        value = "${appLanguage.flag} ${settingsAppLanguageValue(appLanguage)} ›",
        onClick = onClick
    )
}

@Composable
private fun AppLanguageSheet(
    appLanguage: AppLanguage,
    onDismiss: () -> Unit,
    onSelect: (AppLanguage) -> Unit
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.42f))
                    .clickable(onClick = onDismiss)
            )
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clickable(onClick = {}),
                color = Color.White,
                shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
                elevation = 18.dp
            ) {
                Column(
                    modifier = Modifier
                        .navigationBarsPadding()
                        .padding(start = 18.dp, end = 18.dp, top = 8.dp, bottom = 24.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .size(width = 38.dp, height = 4.dp)
                            .background(Color(0xFFD4D8DF), RoundedCornerShape(2.dp))
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = stringResource(R.string.settings_app_language_sheet_title),
                            color = Color(0xFF151821),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.ExtraBold,
                            textAlign = TextAlign.Center
                        )
                        Surface(
                            modifier = Modifier
                                .align(Alignment.CenterEnd)
                                .size(36.dp)
                                .clickable(onClick = onDismiss),
                            color = Color(0xFFF1F3F6),
                            shape = RoundedCornerShape(18.dp),
                            elevation = 0.dp
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    text = "×",
                                    color = Color(0xFF697386),
                                    fontSize = 24.sp,
                                    textAlign = TextAlign.Center
                                )
                            }
                        }
                    }
                    Column {
                        AppLanguageOption(
                            language = AppLanguage.SimplifiedChinese,
                            selected = appLanguage == AppLanguage.SimplifiedChinese,
                            title = stringResource(R.string.settings_app_language_option_chinese_title),
                            subtitle = stringResource(R.string.settings_app_language_option_chinese_subtitle),
                            onSelect = onSelect
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        AppLanguageOption(
                            language = AppLanguage.English,
                            selected = appLanguage == AppLanguage.English,
                            title = stringResource(R.string.settings_app_language_option_english_title),
                            subtitle = stringResource(R.string.settings_app_language_option_english_subtitle),
                            onSelect = onSelect
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AppLanguageOption(
    language: AppLanguage,
    selected: Boolean,
    title: String,
    subtitle: String,
    onSelect: (AppLanguage) -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(76.dp)
            .clickable { onSelect(language) },
        color = if (selected) Color(0xFFEEF6FF) else Color.White,
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, if (selected) Color(0xFF1684F8) else Color(0xFFE2E7EF)),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = language.flag,
                modifier = Modifier.size(width = 38.dp, height = 32.dp),
                fontSize = 26.sp,
                lineHeight = 32.sp
            )
            Column(modifier = Modifier.weight(1f).padding(start = 12.dp)) {
                Text(
                    text = title,
                    color = Color(0xFF151821),
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = subtitle,
                    modifier = Modifier.padding(top = 3.dp),
                    color = Color(0xFF7C8595),
                    fontSize = 12.sp,
                    lineHeight = 16.sp
                )
            }
            Text(
                text = if (selected) "✓" else "",
                color = Color(0xFF1684F8),
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun settingsIdentityStatusLabel(status: AssistantIdentityProfileStatus): String =
    when (status) {
        AssistantIdentityProfileStatus.Empty -> stringResource(R.string.settings_identity_status_not_set)
        AssistantIdentityProfileStatus.Filled -> stringResource(R.string.settings_identity_status_saved)
        AssistantIdentityProfileStatus.Verified -> stringResource(R.string.settings_identity_status_verified)
    }

@Composable
private fun settingsAppLanguageValue(appLanguage: AppLanguage): String =
    when (appLanguage) {
        AppLanguage.English -> stringResource(R.string.settings_app_language_value_english)
        AppLanguage.SimplifiedChinese -> stringResource(R.string.settings_app_language_value_chinese)
    }
