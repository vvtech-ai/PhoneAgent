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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
        FinalBackTitleBar(title = "海外实时翻译", onBack = callbacks.onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 24.dp)
        ) {
            item {
                Text(
                    text = "实时翻译模型",
                    modifier = Modifier.padding(top = 18.dp, bottom = 8.dp),
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "只影响之后新发起的海外实时翻译通话",
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
                    text = "服务部署区域",
                    modifier = Modifier.padding(top = 24.dp, bottom = 8.dp),
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "选择离你更合适的翻译服务节点，只影响后续通话",
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
                    value = if (state.serviceRegion == region) "已选择" else "›",
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

private fun serviceRegionDescription(region: TranslationServiceRegion): String = when (region) {
    TranslationServiceRegion.Default -> "默认服务部署"
    TranslationServiceRegion.UnitedStates -> "美国服务部署"
    TranslationServiceRegion.Japan -> "日本服务部署"
}
