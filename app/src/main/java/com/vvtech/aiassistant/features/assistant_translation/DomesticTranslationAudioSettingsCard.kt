package com.vvtech.aiassistant.features.assistant_translation

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Slider
import androidx.compose.material.Switch
import androidx.compose.material.SwitchDefaults
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalDeveloperModeButtonV3
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.TranslationLanguagePicker
import com.vvtech.aiassistant.features.assistant.TranslationProviderLanguageSettings
import com.vvtech.aiassistant.features.assistant.qwenVoiceLabel
import com.vvtech.aiassistant.features.assistant.translationLanguageLabel
import kotlin.math.roundToInt

internal data class DomesticOriginalAudioSettingsState(
    val enabled: Boolean,
    val gainPercent: Int,
    val volumePercent: Int
)

internal data class DomesticOriginalAudioSettingsCallbacks(
    val onEnabledChange: (Boolean) -> Unit,
    val onGainPercentChange: (Int) -> Unit,
    val onVolumePercentChange: (Int) -> Unit
)

@Composable
internal fun DomesticOriginalAudioSettingsPage(
    state: DomesticOriginalAudioSettingsState,
    callbacks: DomesticOriginalAudioSettingsCallbacks,
    onBack: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "Original Audio", onBack = onBack)
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 14.dp),
            color = Color.White.copy(alpha = 0.80f),
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                OriginalAudioSettings(state, callbacks)
            }
        }
    }
}

@Composable
internal fun DomesticTranslationAudioSettingsCard(
    qwenSelected: Boolean,
    preferredQwenVoice: String,
    languageSettings: TranslationProviderLanguageSettings,
    originalAudioState: DomesticOriginalAudioSettingsState,
    originalAudioCallbacks: DomesticOriginalAudioSettingsCallbacks,
    onSelectQwenVoice: (String) -> Unit,
    onSelectCallerLanguage: (String) -> Unit,
    onSelectCalleeLanguage: (String) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
            OriginalAudioSettings(originalAudioState, originalAudioCallbacks)
            Text(
                text = "Translation Output Voice",
                modifier = Modifier.padding(top = 16.dp),
                color = Color(0xFF111111),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            if (qwenSelected) {
                QwenAudioOptions(
                    preferredQwenVoice = preferredQwenVoice,
                    languageSettings = languageSettings,
                    onSelectQwenVoice = onSelectQwenVoice,
                    onSelectCallerLanguage = onSelectCallerLanguage,
                    onSelectCalleeLanguage = onSelectCalleeLanguage
                )
            } else {
                Text(
                    text = "The Doubao model currently only supports calls using the default cloned user voice and does not provide system voice selection.",
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
        }
    }
}

@Composable
private fun OriginalAudioSettings(
    state: DomesticOriginalAudioSettingsState,
    callbacks: DomesticOriginalAudioSettingsCallbacks
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text("Play Original Audio", color = Color(0xFF111111), fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Text(
                "When enabled, original call audio plays first; translated audio mixes in realtime original audio at the ratio below.",
                modifier = Modifier.padding(top = 6.dp),
                color = Color(0xFF6E6E73),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
        Switch(
            checked = state.enabled,
            onCheckedChange = callbacks.onEnabledChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Color(0xFF0A84FF),
                checkedTrackAlpha = 1f
            )
        )
    }
    OriginalAudioLevelSlider(
        label = "Original Audio Volume",
        percent = state.volumePercent,
        maxPercent = 100,
        steps = 9,
        enabled = state.enabled,
        onPercentChange = callbacks.onVolumePercentChange
    )
    OriginalAudioLevelSlider(
        label = "Original Audio Mix Ratio",
        percent = state.gainPercent,
        maxPercent = 50,
        steps = 4,
        enabled = state.enabled,
        onPercentChange = callbacks.onGainPercentChange
    )
    Text(
        text = "Adjusts in 10% steps and only affects the next live translation call.",
        color = Color(0xFF6E6E73),
        fontSize = 12.sp,
        lineHeight = 18.sp
    )
}

@Composable
private fun OriginalAudioLevelSlider(
    label: String,
    percent: Int,
    maxPercent: Int,
    steps: Int,
    enabled: Boolean,
    onPercentChange: (Int) -> Unit
) {
    Text(
        text = "$label：$percent%",
        modifier = Modifier.padding(top = 14.dp),
        color = Color(0xFF111111),
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold
    )
    Slider(
        value = percent.toFloat(),
        onValueChange = { onPercentChange((it / 10f).roundToInt() * 10) },
        modifier = Modifier.fillMaxWidth(),
        enabled = enabled,
        valueRange = 0f..maxPercent.toFloat(),
        steps = steps
    )
}

@Composable
private fun QwenAudioOptions(
    preferredQwenVoice: String,
    languageSettings: TranslationProviderLanguageSettings,
    onSelectQwenVoice: (String) -> Unit,
    onSelectCallerLanguage: (String) -> Unit,
    onSelectCalleeLanguage: (String) -> Unit
) {
    Text(
        "For Qwen, you can switch between female and male system voices. This setting is saved only on this device.",
        modifier = Modifier.padding(top = 6.dp),
        color = Color(0xFF6E6E73),
        fontSize = 13.sp
    )
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        listOf("Cherry", "Nofish").forEach { voice ->
            FinalDeveloperModeButtonV3(
                label = qwenVoiceLabel(voice),
                selected = preferredQwenVoice == voice,
                onClick = { onSelectQwenVoice(voice) },
                modifier = Modifier.weight(1f)
            )
        }
    }
    Text("Default Translation Languages", modifier = Modifier.padding(top = 16.dp), fontWeight = FontWeight.Bold)
    LanguagePicker("My Language", languageSettings.callerLanguage, onSelectCallerLanguage)
    LanguagePicker("Other Side Language", languageSettings.calleeLanguage, onSelectCalleeLanguage)
}

@Composable
private fun LanguagePicker(label: String, language: String, onSelected: (String) -> Unit) {
    Text(
        "$label: ${translationLanguageLabel(language)}",
        modifier = Modifier.padding(top = 12.dp),
        color = Color(0xFF344054),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium
    )
    Spacer(modifier = Modifier.size(8.dp))
    TranslationLanguagePicker(selected = language, onSelected = onSelected)
}
