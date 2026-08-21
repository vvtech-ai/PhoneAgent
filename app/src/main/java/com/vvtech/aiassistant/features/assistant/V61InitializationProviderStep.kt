package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.RadioButton
import androidx.compose.material.RadioButtonDefaults
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
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog

internal data class V61ProviderOption(
    val id: String,
    val title: String,
    val subtitle: String,
    val enabled: Boolean
)

internal val V61CallProviderOptions = listOf(
    V61ProviderOption(
        "QWEN_OMNI_PLUS",
        AssistantCallModelDisplayNames.Qwen,
        "Alibaba · full-duplex voice conversation engine",
        true
    ),
    V61ProviderOption(
        "DOUBAO",
        AssistantCallModelDisplayNames.Doubao,
        "ByteDance · end-to-end duplex voice model",
        true
    ),
    V61ProviderOption("GPT", "GPT Realtime", "Coming soon · overseas", false)
)

internal val V61TranslationProviderOptions =
    TranslationProviderUiCatalog.allOptions.map { option ->
        V61ProviderOption(
            id = option.id,
            title = option.displayName,
            subtitle = if (option.enabledDuringInitialization) {
                "同声传译模型"
            } else {
                "即将支持 · 适用于海外"
            },
            enabled = option.enabledDuringInitialization
        )
    }

@Composable
internal fun V61ProviderStep(
    title: String,
    subtitle: String,
    selected: String,
    options: List<V61ProviderOption>,
    primaryLabel: String,
    error: String? = null,
    onSelected: (String) -> Unit,
    onContinue: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = title,
            modifier = Modifier.padding(top = 34.dp),
            color = Color(0xFF111111),
            fontSize = 22.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = subtitle,
            modifier = Modifier.padding(top = 8.dp, bottom = 30.dp),
            color = Color(0xFF667085),
            fontSize = 14.sp
        )
        options.forEach { option ->
            V61ProviderCard(option, selected == option.id, onSelected)
        }
        if (!error.isNullOrBlank()) {
            Text(
                text = error,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp),
                color = Color(0xFFE14D46),
                fontSize = 13.sp
            )
        }
        Spacer(modifier = Modifier.weight(1f))
        FinalActionButton(
            label = primaryLabel,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 20.dp, bottom = 36.dp),
            onClick = onContinue
        )
    }
}

@Composable
private fun V61ProviderCard(
    option: V61ProviderOption,
    selected: Boolean,
    onSelected: (String) -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .clickable(enabled = option.enabled) { onSelected(option.id) },
        color = when {
            !option.enabled -> Color(0xFFF7F7F8)
            selected -> Color(0x0F2196F3)
            else -> Color.White
        },
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(
            1.dp,
            when {
                selected && option.enabled -> Color(0xFF2196F3)
                option.enabled -> Color(0xFFE2E8F0)
                else -> Color(0xFFE5E7EB)
            }
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 15.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    option.title,
                    color = if (option.enabled) Color(0xFF111111) else Color(0xFF9B9BA1),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    localizedV61ProviderSubtitle(option),
                    modifier = Modifier.padding(top = 5.dp),
                    color = if (option.enabled) Color(0xFF667085) else Color(0xFFAEAEB2),
                    fontSize = 12.sp
                )
            }
            RadioButton(
                selected = selected && option.enabled,
                onClick = null,
                enabled = option.enabled,
                colors = RadioButtonDefaults.colors(
                    selectedColor = Color(0xFF2196F3),
                    unselectedColor = Color(0xFF98A2B3),
                    disabledColor = Color(0xFFCCD3DE)
                )
            )
        }
    }
}

@Composable
private fun localizedV61ProviderSubtitle(option: V61ProviderOption): String = when (option.id) {
    "QWEN_OMNI_PLUS" -> stringResource(R.string.call_model_qwen_description)
    "DOUBAO" -> stringResource(R.string.call_model_seeduplex_description)
    "GPT" -> stringResource(R.string.call_model_gpt_coming_soon)
    TranslationProviderUiCatalog.OpenAiId -> stringResource(R.string.translation_provider_gpt_subtitle)
    TranslationProviderUiCatalog.GeminiId -> stringResource(R.string.translation_provider_gemini_subtitle)
    else -> option.subtitle
}
