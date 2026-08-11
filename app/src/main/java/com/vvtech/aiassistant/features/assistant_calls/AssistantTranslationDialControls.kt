package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState

@Composable
internal fun AssistantDialTranslationToggleSection(
    translateEnabled: Boolean,
    translationProviderTitle: String,
    onOpenTranslationProvider: () -> Unit,
    onTranslateToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        AssistantTranslationModelEntry(
            title = v61DialModelDisplayName(translationProviderTitle),
            onOpen = onOpenTranslationProvider
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("实时翻译通话", color = Color(0xFF374151), fontSize = 13.sp, fontWeight = FontWeight.Medium)
            AssistantTranslationToggle(checked = translateEnabled, onCheckedChange = onTranslateToggle)
        }
    }
}

private fun v61DialModelDisplayName(raw: String): String =
    TranslationProviderUiCatalog.option(raw)?.displayName
        ?: raw.ifBlank { TranslationProviderUiCatalog.displayName(null) }

@Composable
private fun AssistantTranslationToggle(checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Surface(
        modifier = Modifier
            .size(width = 38.dp, height = 20.dp)
            .clickable { onCheckedChange(!checked) },
        color = if (checked) Color(0xFF6C5CE7) else Color(0xFFD1D5DB),
        shape = RoundedCornerShape(12.dp),
        elevation = 0.dp
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .align(Alignment.CenterStart)
                    .offset(x = if (checked) 20.dp else 2.dp)
                    .background(Color.White, RoundedCornerShape(50))
            )
        }
    }
}

@Composable
internal fun AssistantTranslationModelEntry(
    title: String,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.clickable(onClick = onOpen),
        color = Color.Transparent,
        shape = RoundedCornerShape(4.dp),
        elevation = 0.dp
    ) {
        Text(
            text = "$title ▾",
            modifier = Modifier.padding(vertical = 6.dp),
            color = Color(0xFF344054),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
internal fun AssistantTranslationModelSheetHost(
    visible: Boolean,
    selectedProvider: String,
    availableProviders: Set<String>,
    quality: TranslationModelNetworkQualityState,
    onRefresh: () -> Unit,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    if (!visible) return
    AssistantTranslationModelSheet(
        selectedProvider = translationModelSheetProvider(selectedProvider),
        availableProviders = translationModelSheetAvailableProviders(availableProviders),
        quality = quality,
        onRefresh = onRefresh,
        onSelect = onSelect,
        onDismiss = onDismiss
    )
}

internal fun translationModelSheetProvider(provider: String?): String =
    TranslationProviderUiCatalog.normalizeProviderId(provider)

internal fun translationModelSheetAvailableProviders(providers: Set<String>): Set<String> =
    providers.mapNotNullTo(linkedSetOf()) { provider ->
        TranslationProviderUiCatalog.option(provider)?.id
    }
