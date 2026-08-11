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
        FinalBackTitleBar(title = "实时翻译原音", onBack = onBack)
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
                text = "\u7ffb\u8bd1\u8f93\u51fa\u97f3\u8272",
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
                    text = "\u8c46\u5305\u6a21\u578b\u5f53\u524d\u4ec5\u652f\u6301\u9ed8\u8ba4\u590d\u523b\u7528\u6237\u97f3\u8272\u901a\u8bdd\uff0c\u4e0d\u63d0\u4f9b\u7cfb\u7edf\u97f3\u8272\u9009\u62e9\u3002",
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
            Text("播放原声", color = Color(0xFF111111), fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Text(
                "开启后先播放通话原声；译音播放时按下方比例混合当前实时原声。",
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
        label = "纯原声播放声音大小",
        percent = state.volumePercent,
        maxPercent = 100,
        steps = 9,
        enabled = state.enabled,
        onPercentChange = callbacks.onVolumePercentChange
    )
    OriginalAudioLevelSlider(
        label = "混声时原声比例",
        percent = state.gainPercent,
        maxPercent = 50,
        steps = 4,
        enabled = state.enabled,
        onPercentChange = callbacks.onGainPercentChange
    )
    Text(
        text = "均按 10% 步进调节，仅影响下一通实时翻译通话。",
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
        "Qwen 模型下可切换女声 / 男声，只保存在当前设备。",
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
    Text("默认翻译语种", modifier = Modifier.padding(top = 16.dp), fontWeight = FontWeight.Bold)
    LanguagePicker("我方语种", languageSettings.callerLanguage, onSelectCallerLanguage)
    LanguagePicker("对方语种", languageSettings.calleeLanguage, onSelectCalleeLanguage)
}

@Composable
private fun LanguagePicker(label: String, language: String, onSelected: (String) -> Unit) {
    Text(
        "$label：${translationLanguageLabel(language)}",
        modifier = Modifier.padding(top = 12.dp),
        color = Color(0xFF344054),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium
    )
    Spacer(modifier = Modifier.size(8.dp))
    TranslationLanguagePicker(selected = language, onSelected = onSelected)
}
