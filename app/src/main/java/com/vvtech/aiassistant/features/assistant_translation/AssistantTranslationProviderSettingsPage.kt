package com.vvtech.aiassistant.features.assistant_translation

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.features.assistant.FinalActionButton
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.FinalButtonTone
import com.vvtech.aiassistant.features.assistant.TranslationProviderLanguageSettings
import com.vvtech.aiassistant.features.assistant.sanitizeTranslationSettingsUiDisplayTextFinal
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse

@Composable
internal fun AssistantTranslationProviderSettingsPage(
    providerResponse: RealtimeTranslationProviderResponse?,
    loading: Boolean,
    switching: Boolean,
    error: String?,
    preferredQwenVoice: String,
    qwenLanguageSettings: TranslationProviderLanguageSettings,
    originalAudioState: DomesticOriginalAudioSettingsState,
    originalAudioCallbacks: DomesticOriginalAudioSettingsCallbacks,
    onSelectQwenVoice: (String) -> Unit,
    onSelectCallerLanguage: (String) -> Unit,
    onSelectCalleeLanguage: (String) -> Unit,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onSelectProvider: (String) -> Unit
) {
    val activeProvider = providerResponse?.activeProvider.orEmpty()
    val qwenSelected =
        TranslationProviderUiCatalog.option(activeProvider)?.provider ==
            TranslationRealtimeProvider.Qwen
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = stringResource(R.string.dial_live_translation_title), onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 16.dp)
        ) {
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp, bottom = 10.dp),
                    color = Color.White.copy(alpha = 0.80f),
                    shape = RoundedCornerShape(24.dp),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
                    elevation = 0.dp
                ) {
                    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                        Text(
                            text = stringResource(R.string.translation_provider_switch_title),
                            color = Color(0xFF111111),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = stringResource(R.string.translation_provider_voice_note),
                            modifier = Modifier.padding(top = 8.dp),
                            color = Color(0xFF6E6E73),
                            fontSize = 13.sp,
                            lineHeight = 18.sp
                        )
                    }
                }
            }
            if (loading && providerResponse == null) {
                item {
                    Text(
                        text = stringResource(R.string.translation_provider_loading),
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 13.sp
                    )
                }
            }
            if (!error.isNullOrBlank()) {
                item {
                    Text(
                        text = error,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp
                    )
                }
            }
            items(providerResponse?.providers.orEmpty(), key = { it.provider }) { provider ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp),
                    color = Color.White.copy(alpha = 0.80f),
                    shape = RoundedCornerShape(24.dp),
                    border = BorderStroke(
                        1.dp,
                        if (provider.active) Color(0x55007AFF) else Color.White.copy(alpha = 0.78f)
                    ),
                    elevation = 0.dp
                ) {
                    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = TranslationProviderUiCatalog
                                        .option(provider.provider)
                                        ?.displayName
                                        ?: sanitizeTranslationSettingsUiDisplayTextFinal(
                                            provider.displayName
                                        ),
                                    color = Color(0xFF111111),
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = provider.statusMessage.ifBlank { "\u5f85\u68c0\u67e5" },
                                    modifier = Modifier.padding(top = 6.dp),
                                    color = Color(0xFF6E6E73),
                                    fontSize = 12.sp,
                                    lineHeight = 18.sp
                                )
                            }
                            Surface(
                                color = if (provider.active) Color(0x1A007AFF) else Color(0xFFF2F4F7),
                                shape = RoundedCornerShape(999.dp),
                                elevation = 0.dp
                            ) {
                                Text(
                                    text = when {
                                        provider.active -> "\u5f53\u524d\u4f7f\u7528"
                                        !provider.available -> "\u6682\u4e0d\u53ef\u7528"
                                        else -> "\u53ef\u5207\u6362"
                                    },
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    color = if (provider.active) Color(0xFF0A84FF) else Color(0xFF667085),
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                        Text(
                            text = "\u914d\u7f6e\u72b6\u6001\uff1a${if (provider.configured) "\u5df2\u914d\u7f6e" else "\u7f3a\u5c11\u914d\u7f6e"} \u00b7 \u53ef\u7528\u6027\uff1a${if (provider.available) "\u53ef\u7528" else "\u4e0d\u53ef\u7528"}",
                            modifier = Modifier.padding(top = 10.dp),
                            color = Color(0xFF6E6E73),
                            fontSize = 13.sp,
                            lineHeight = 18.sp
                        )
                        FinalActionButton(
                            label = when {
                                switching && provider.active -> "\u5207\u6362\u4e2d..."
                                provider.active -> "\u5f53\u524d\u6a21\u578b"
                                !provider.available -> "\u6682\u4e0d\u53ef\u5207\u6362"
                                else -> "\u5207\u6362\u5230\u6b64\u6a21\u578b"
                            },
                            tone = if (provider.active) FinalButtonTone.Secondary else FinalButtonTone.Primary,
                            enabled = !switching && !loading && provider.available && !provider.active,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 14.dp),
                            onClick = { onSelectProvider(provider.provider) }
                        )
                    }
                }
            }
            item {
                DomesticTranslationAudioSettingsCard(
                    qwenSelected = qwenSelected,
                    preferredQwenVoice = preferredQwenVoice,
                    languageSettings = qwenLanguageSettings,
                    originalAudioState = originalAudioState,
                    originalAudioCallbacks = originalAudioCallbacks,
                    onSelectQwenVoice = onSelectQwenVoice,
                    onSelectCallerLanguage = onSelectCallerLanguage,
                    onSelectCalleeLanguage = onSelectCalleeLanguage
                )
            }
            item {
                FinalActionButton(
                    label = if (loading) "\u5237\u65b0\u4e2d..." else "\u5237\u65b0\u72b6\u6001",
                    tone = FinalButtonTone.Secondary,
                    enabled = !loading && !switching,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp, bottom = 8.dp),
                    onClick = onRefresh
                )
            }
        }
    }
}
