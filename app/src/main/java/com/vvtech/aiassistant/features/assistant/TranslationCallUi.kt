package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.runtime.Composable
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.core.model.TranslationLanguageMode
import com.vvtech.aiassistant.core.model.TranslationVoiceCapabilitiesResponse
import com.vvtech.aiassistant.core.model.TranslationVoiceMode

internal data class TranslationCallDraft(
    val phoneNumber: String = "",
    val displayName: String = "",
    val languageMode: TranslationLanguageMode = TranslationLanguageMode.AUTO,
    val callerLanguage: String = "zh",
    val calleeLanguage: String = "en",
    val voiceMode: TranslationVoiceMode = TranslationVoiceMode.DEFAULT,
    val preferredVoice: String = ""
)

internal val TranslationCallDraftSaver: Saver<TranslationCallDraft, Any> = listSaver(
    save = { draft ->
        listOf(
            draft.phoneNumber,
            draft.displayName,
            draft.languageMode.name,
            draft.callerLanguage,
            draft.calleeLanguage,
            draft.voiceMode.name,
            draft.preferredVoice
        )
    },
    restore = { restored ->
        TranslationCallDraft(
            phoneNumber = restored.getOrNull(0) as? String ?: "",
            displayName = restored.getOrNull(1) as? String ?: "",
            languageMode = (restored.getOrNull(2) as? String)
                ?.let(TranslationLanguageMode::valueOf)
                ?: TranslationLanguageMode.AUTO,
            callerLanguage = restored.getOrNull(3) as? String ?: "zh",
            calleeLanguage = restored.getOrNull(4) as? String ?: "en",
            voiceMode = (restored.getOrNull(5) as? String)
                ?.let(TranslationVoiceMode::valueOf)
                ?: TranslationVoiceMode.DEFAULT,
            preferredVoice = restored.getOrNull(6) as? String ?: ""
        )
    }
)

@Composable
internal fun FinalTranslationDialPage(
    draft: TranslationCallDraft,
    capabilities: TranslationVoiceCapabilitiesResponse?,
    loading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onPhoneChange: (String) -> Unit,
    onDisplayNameChange: (String) -> Unit,
    onLanguageModeChange: (TranslationLanguageMode) -> Unit,
    onCallerLanguageChange: (String) -> Unit,
    onCalleeLanguageChange: (String) -> Unit,
    onVoiceModeChange: (TranslationVoiceMode) -> Unit,
    onPreferredVoiceChange: (String) -> Unit,
    onStartCall: () -> Unit,
    onRefreshCapabilities: () -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF6F8FB))
            .navigationBarsPadding(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            TranslationTopBar(title = stringResource(R.string.translation_dial_title), onBack = onBack)
        }
        item {
            TranslationSectionCard {
                Text(stringResource(R.string.translation_phone_label), fontSize = 14.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                TranslationTextField(
                    value = draft.phoneNumber,
                    placeholder = stringResource(R.string.translation_phone_placeholder),
                    onValueChange = onPhoneChange
                )
                Spacer(Modifier.height(10.dp))
                Text(stringResource(R.string.translation_display_name_label), fontSize = 14.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                TranslationTextField(
                    value = draft.displayName,
                    placeholder = stringResource(R.string.translation_display_name_placeholder),
                    onValueChange = onDisplayNameChange
                )
            }
        }
        item {
            TranslationSectionCard {
                Text(stringResource(R.string.translation_service_label), fontSize = 14.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                Text(
                    text = capabilities?.provider ?: if (loading) {
                        stringResource(R.string.translation_loading)
                    } else {
                        stringResource(R.string.translation_not_loaded)
                    },
                    fontSize = 18.sp,
                    color = Color(0xFF111827),
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = when {
                        capabilities == null && loading -> stringResource(R.string.translation_capability_checking)
                        capabilities == null -> stringResource(R.string.translation_capability_failed)
                        !capabilities.translationSupported -> stringResource(R.string.translation_capability_unsupported)
                        else -> stringResource(R.string.translation_capability_supported)
                    },
                    fontSize = 13.sp,
                    color = Color(0xFF667085)
                )
                if (!error.isNullOrBlank()) {
                    Spacer(Modifier.height(8.dp))
                    Text(error, color = Color(0xFFB42318), fontSize = 13.sp)
                }
                Spacer(Modifier.height(10.dp))
                TranslationGhostButton(label = stringResource(R.string.translation_refresh_capability), onClick = onRefreshCapabilities)
            }
        }
        item {
            TranslationSectionCard {
                Text(stringResource(R.string.translation_language_mode), fontSize = 14.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                TranslationSegmentedRow(
                    options = listOf(
                        "AUTO" to stringResource(R.string.translation_mode_auto),
                        "MANUAL" to stringResource(R.string.translation_mode_manual)
                    ),
                    selected = draft.languageMode.name,
                    onSelected = { key -> onLanguageModeChange(TranslationLanguageMode.valueOf(key)) }
                )
                if (draft.languageMode == TranslationLanguageMode.MANUAL) {
                    Spacer(Modifier.height(12.dp))
                    Text(stringResource(R.string.translation_your_language), fontSize = 13.sp, color = Color(0xFF667085))
                    Spacer(Modifier.height(8.dp))
                    TranslationLanguagePicker(
                        selected = draft.callerLanguage,
                        onSelected = onCallerLanguageChange
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(R.string.translation_other_language), fontSize = 13.sp, color = Color(0xFF667085))
                    Spacer(Modifier.height(8.dp))
                    TranslationLanguagePicker(
                        selected = draft.calleeLanguage,
                        onSelected = onCalleeLanguageChange
                    )
                } else {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        stringResource(R.string.translation_auto_language_hint),
                        fontSize = 13.sp,
                        color = Color(0xFF667085)
                    )
                }
            }
        }
        if (FinalVoiceCloneFeatureVisible) {
            item {
                TranslationSectionCard {
                    Text(stringResource(R.string.translation_voice_title), fontSize = 14.sp, color = Color(0xFF667085))
                    Spacer(Modifier.height(8.dp))
                    val capability = capabilities?.voiceCapability.orEmpty()
                    when (capability) {
                        "USER_VOICE_CLONE_SUPPORTED" -> {
                            TranslationSegmentedRow(
                                options = listOf(
                                    "DEFAULT" to stringResource(R.string.translation_voice_default),
                                    "USER_CLONE" to stringResource(R.string.translation_voice_user_clone)
                                ),
                                selected = draft.voiceMode.name,
                                onSelected = { key -> onVoiceModeChange(TranslationVoiceMode.valueOf(key)) }
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                stringResource(R.string.translation_voice_clone_supported),
                                fontSize = 13.sp,
                                color = Color(0xFF667085)
                            )
                        }
                        "SOURCE_VOICE_MIMIC_ONLY" -> Text(
                            stringResource(R.string.translation_voice_mimic_only),
                            fontSize = 13.sp,
                            color = Color(0xFF667085)
                        )
                        "BUILT_IN_VOICE_ONLY" -> Text(
                            stringResource(R.string.translation_voice_builtin_only),
                            fontSize = 13.sp,
                            color = Color(0xFF667085)
                        )
                        else -> Text(
                            stringResource(R.string.translation_voice_not_available),
                            fontSize = 13.sp,
                            color = Color(0xFF667085)
                        )
                    }
                    if (!capabilities?.builtInVoices.isNullOrEmpty()) {
                        Spacer(Modifier.height(12.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            capabilities?.builtInVoices
                                ?.chunked(3)
                                ?.forEach { rowVoices ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        rowVoices.forEach { voice ->
                                            TranslationChip(
                                                label = voice,
                                                selected = draft.preferredVoice == voice,
                                                onClick = { onPreferredVoiceChange(voice) }
                                            )
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        item {
            TranslationPrimaryButton(
                label = stringResource(R.string.translation_start_call),
                enabled = capabilities?.translationSupported == true && draft.phoneNumber.isNotBlank(),
                onClick = onStartCall
            )
        }
    }
}

@Composable
internal fun FinalTranslationCallPage(
    seconds: Int,
    status: TranslationCallStatusResponse?,
    error: String?,
    audioChannelStatus: String?,
    callerLanguageDraft: String,
    calleeLanguageDraft: String,
    onBack: () -> Unit,
    onCallerLanguageChange: (String) -> Unit,
    onCalleeLanguageChange: (String) -> Unit,
    onApplyOverride: () -> Unit,
    onRefresh: () -> Unit,
    onHangup: () -> Unit
) {
    val connectingChannelText = stringResource(R.string.translation_connecting_channel)
    val passthroughSameLanguageText = stringResource(R.string.translation_passthrough_same_language)
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0B1220))
            .navigationBarsPadding(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            TranslationTopBar(title = stringResource(R.string.translation_calling_title), onBack = onBack, dark = true)
        }
        item {
            Surface(
                color = Color.White.copy(alpha = 0.08f),
                shape = RoundedCornerShape(28.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp)
                ) {
                    Text(
                        text = formatSeconds(seconds),
                        color = Color.White,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = localizedTranslationCallMessage(status?.statusMessage)
                            .ifBlank { connectingChannelText },
                        color = Color(0xFFD0D5DD),
                        fontSize = 14.sp
                    )
                    if (status?.passthroughActive == true) {
                        Spacer(Modifier.height(10.dp))
                        Surface(
                            color = Color(0x1AFFD166),
                            shape = RoundedCornerShape(999.dp)
                        ) {
                            Text(
                                text = localizedTranslationCallMessage(status.passthroughReason)
                                    .ifBlank { passthroughSameLanguageText },
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                                color = Color(0xFFFFD166),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    TranslationStatusPill(stringResource(R.string.translation_call_status), localizedTranslationCallState(status?.callState))
                    Spacer(Modifier.height(8.dp))
                    TranslationStatusPill(stringResource(R.string.translation_session_status), localizedTranslationSessionState(status?.translationState))
                    Spacer(Modifier.height(8.dp))
                    TranslationStatusPill(stringResource(R.string.translation_model_label), status?.provider ?: "--")
                    if (FinalVoiceCloneFeatureVisible) {
                        Spacer(Modifier.height(8.dp))
                        TranslationStatusPill(
                            stringResource(R.string.translation_voice_label),
                            if (status?.voiceCapability == "SOURCE_VOICE_MIMIC_ONLY") {
                                stringResource(R.string.translation_voice_follow_remote)
                            } else {
                                status?.effectiveCallerToCalleeVoice ?: "--"
                            }
                        )
                    }
                    if (!audioChannelStatus.isNullOrBlank()) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = audioChannelStatus,
                            color = Color(0xFF98A2B3),
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }
        item {
            TranslationSectionCard(containerColor = Color.White) {
                Text(stringResource(R.string.translation_language_detection), fontSize = 15.sp, color = Color(0xFF111827), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(10.dp))
                TranslationStatusRow(stringResource(R.string.translation_your_language), displayLanguageLabel(status?.callerDetectedLanguage))
                Spacer(Modifier.height(8.dp))
                TranslationStatusRow(stringResource(R.string.translation_other_language), displayLanguageLabel(status?.calleeDetectedLanguage))
            }
        }
        item {
            TranslationSectionCard(containerColor = Color.White) {
                Text(stringResource(R.string.translation_manual_language_fix), fontSize = 15.sp, color = Color(0xFF111827), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(10.dp))
                Text(stringResource(R.string.translation_your_language), fontSize = 13.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                TranslationLanguagePicker(selected = callerLanguageDraft, onSelected = onCallerLanguageChange)
                Spacer(Modifier.height(10.dp))
                Text(stringResource(R.string.translation_other_language), fontSize = 13.sp, color = Color(0xFF667085))
                Spacer(Modifier.height(8.dp))
                TranslationLanguagePicker(selected = calleeLanguageDraft, onSelected = onCalleeLanguageChange)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    TranslationGhostButton(label = stringResource(R.string.translation_refresh_status), onClick = onRefresh, modifier = Modifier.weight(1f))
                    TranslationPrimaryButton(label = stringResource(R.string.translation_apply_correction), onClick = onApplyOverride, modifier = Modifier.weight(1f))
                }
            }
        }
        item {
            TranslationSectionCard(containerColor = Color.White) {
                Text(stringResource(R.string.translation_subtitles), fontSize = 15.sp, color = Color(0xFF111827), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(10.dp))
                if (status?.subtitleItems.isNullOrEmpty()) {
                    Text(
                        stringResource(R.string.translation_empty_subtitles),
                        fontSize = 13.sp,
                        color = Color(0xFF667085)
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        status?.subtitleItems?.forEach { item ->
                            Surface(
                                color = Color(0xFFF8FAFC),
                                shape = RoundedCornerShape(16.dp)
                            ) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(12.dp)
                                ) {
                                    Text(
                                        translationSubtitleRoleLabel(item.speakerRole),
                                        color = Color(0xFF475467),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                    Spacer(Modifier.height(6.dp))
                                    Text(
                                        stringResource(
                                            R.string.translation_source_text_label,
                                            displayLanguageLabel(item.sourceLanguage)
                                        ),
                                        color = Color(0xFF475467),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                    Spacer(Modifier.height(4.dp))
                                    Text(item.sourceText.ifBlank { "--" }, color = Color(0xFF111827), fontSize = 14.sp)
                                    if (item.translatedText.isNotBlank() && item.translatedText != item.sourceText) {
                                        Spacer(Modifier.height(10.dp))
                                        Text(
                                            stringResource(
                                                R.string.translation_translated_text_label,
                                                displayLanguageLabel(item.translatedLanguage)
                                            ),
                                            color = Color(0xFF475467),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium
                                        )
                                        Spacer(Modifier.height(4.dp))
                                        Text(item.translatedText.ifBlank { "--" }, color = Color(0xFF1570EF), fontSize = 14.sp)
                                    }
                                }
                            }
                        }
                    }
                }
                if (!error.isNullOrBlank()) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        localizedTranslationCallMessage(error).ifBlank { error },
                        color = Color(0xFFB42318),
                        fontSize = 13.sp
                    )
                }
            }
        }
        item {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = Color(0xFFEF4444),
                shape = RoundedCornerShape(22.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onHangup)
                        .padding(vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(Icons.Rounded.CallEnd, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.translation_hangup), color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
