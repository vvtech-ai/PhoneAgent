package com.vvtech.aiassistant.features.translation_call.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.FinalDeveloperModeButtonV3
import com.vvtech.aiassistant.features.assistant.FinalSettingCardV3
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog

data class OverseasTranslationSettingsUiState(
    val provider: TranslationRealtimeProvider,
    val serviceRegion: TranslationServiceRegion
)

data class OverseasTranslationSettingsCallbacks(
    val onBack: () -> Unit,
    val onSelectProvider: (TranslationRealtimeProvider) -> Unit,
    val onSelectServiceRegion: (TranslationServiceRegion) -> Unit
)

@Composable
fun OverseasTranslationSettingsPage(
    state: OverseasTranslationSettingsUiState,
    callbacks: OverseasTranslationSettingsCallbacks
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = stringResource(R.string.translation_settings_title), onBack = callbacks.onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 24.dp)
        ) {
            item {
                Text(
                    text = stringResource(R.string.translation_settings_model_title),
                    modifier = Modifier.padding(top = 18.dp, bottom = 8.dp),
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = stringResource(R.string.translation_settings_model_description),
                    modifier = Modifier.padding(bottom = 12.dp),
                    color = Color(0xFF667085),
                    fontSize = 13.sp
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    listOf(
                        TranslationRealtimeProvider.OpenAi,
                        TranslationRealtimeProvider.Gemini
                    ).forEach { provider ->
                        FinalDeveloperModeButtonV3(
                            label = translationProviderLabel(provider),
                            selected = state.provider == provider,
                            onClick = { callbacks.onSelectProvider(provider) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
            item {
                Text(
                    text = stringResource(R.string.translation_settings_region_title),
                    modifier = Modifier.padding(top = 24.dp, bottom = 8.dp),
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = stringResource(R.string.translation_settings_region_description),
                    modifier = Modifier.padding(bottom = 8.dp),
                    color = Color(0xFF667085),
                    fontSize = 13.sp
                )
            }
            items(TranslationServiceRegion.values().size) { index ->
                val region = TranslationServiceRegion.values()[index]
                FinalSettingCardV3(
                    title = translationServiceRegionLabel(region),
                    subtitle = serviceRegionDescription(region),
                    value = if (state.serviceRegion == region) {
                        stringResource(R.string.translation_settings_selected)
                    } else {
                        "›"
                    },
                    onClick = { callbacks.onSelectServiceRegion(region) }
                )
            }
        }
    }
}

fun translationProviderLabel(provider: TranslationRealtimeProvider): String =
    TranslationProviderUiCatalog.displayName(provider)

fun translationServiceRegionLabel(region: TranslationServiceRegion): String = when (region) {
    TranslationServiceRegion.Default -> "Default"
    TranslationServiceRegion.UnitedStates -> "US"
    TranslationServiceRegion.Japan -> "JP"
}

@Composable
private fun serviceRegionDescription(region: TranslationServiceRegion): String = when (region) {
    TranslationServiceRegion.Default -> stringResource(R.string.translation_region_default_description)
    TranslationServiceRegion.UnitedStates -> stringResource(R.string.translation_region_us_description)
    TranslationServiceRegion.Japan -> stringResource(R.string.translation_region_japan_description)
}
