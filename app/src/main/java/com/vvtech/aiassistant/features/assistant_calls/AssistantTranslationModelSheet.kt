package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.RadioButton
import androidx.compose.material.RadioButtonDefaults
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityPolicy
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState
import com.vvtech.aiassistant.features.model_quality.ModelLatencyPill
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiOption
import com.vvtech.aiassistant.features.translation_call.ui.localizedSubtitle

@Composable
internal fun AssistantTranslationModelSheet(
    selectedProvider: String,
    availableProviders: Set<String>,
    quality: TranslationModelNetworkQualityState,
    onRefresh: () -> Unit,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .testTag("translation-model-backdrop")
            .background(TranslationModelSheetColors.Scrim)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss
            ),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .clickable(remember { MutableInteractionSource() }, null) {},
            color = Color.White,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
            elevation = 0.dp
        ) {
            Column(
                Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 32.dp)
            ) {
                TranslationModelSheetHeader(
                    refreshing = quality.refreshing,
                    onRefresh = onRefresh,
                    onDismiss = onDismiss
                )
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TranslationProviderUiCatalog.allOptions.forEach { option ->
                        val enabled = option.id in availableProviders
                        TranslationModelOptionRow(
                            option = option,
                            quality = quality.components[option.provider],
                            selected = enabled && option.id == selectedProvider,
                            enabled = enabled,
                            onSelect = {
                                onSelect(option.id)
                                onDismiss()
                            }
                        )
                    }
                }
                Text(
                    text = stringResource(R.string.translation_model_sheet_next_call_note),
                    modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                    color = TranslationModelSheetColors.TextSecondary,
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun TranslationModelSheetHeader(
    refreshing: Boolean,
    onRefresh: () -> Unit,
    onDismiss: () -> Unit
) {
    val transition = rememberInfiniteTransition(label = "translationModelRefresh")
    val rotation by transition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(900, easing = LinearEasing)),
        label = "translationModelRefreshRotation"
    )
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = stringResource(R.string.translation_model_sheet_title),
            modifier = Modifier.weight(1f),
            color = TranslationModelSheetColors.TextPrimary,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold
        )
        IconButton(
            onClick = onRefresh,
            enabled = !refreshing,
            modifier = Modifier.size(44.dp).testTag("translation-model-refresh")
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_translation_model_refresh),
                contentDescription = if (refreshing) {
                    stringResource(R.string.translation_model_refreshing_content_description)
                } else {
                    stringResource(R.string.translation_model_refresh_content_description)
                },
                modifier = Modifier.size(22.dp).rotate(if (refreshing) rotation else 0f),
                tint = if (refreshing) Color(0xFF9CA3AF) else TranslationModelSheetColors.Primary
            )
        }
        IconButton(
            onClick = onDismiss,
            modifier = Modifier.size(44.dp).testTag("translation-model-close")
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = stringResource(R.string.common_close),
                modifier = Modifier.size(22.dp),
                tint = Color(0xFF999999)
            )
        }
    }
}

@Composable
private fun TranslationModelOptionRow(
    option: TranslationProviderUiOption,
    quality: TranslationEnvironmentComponent?,
    selected: Boolean,
    enabled: Boolean,
    onSelect: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .testTag(
                if (enabled) {
                    "translation-model-option-enabled-${option.id}"
                } else {
                    "translation-model-option-unavailable-${option.id}"
                }
            )
            .clickable(enabled = enabled, onClick = onSelect),
        color = if (selected) TranslationModelSheetColors.SelectedSurface else Color.White,
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(
            1.5.dp,
            if (selected) TranslationModelSheetColors.Primary else TranslationModelSheetColors.Border
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = option.displayName,
                        color = if (enabled) {
                            TranslationModelSheetColors.TextPrimary
                        } else {
                            Color(0xFF9B9BA1)
                        },
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    ModelLatencyPill(
                        reading = TranslationModelNetworkQualityPolicy.reading(quality)
                    )
                }
                Text(
                    text = option.localizedSubtitle(),
                    modifier = Modifier.padding(top = 2.dp),
                    color = if (enabled) {
                        TranslationModelSheetColors.TextSecondary
                    } else {
                        Color(0xFF9CA3AF)
                    },
                    fontSize = 12.sp
                )
            }
            RadioButton(
                selected = selected,
                onClick = null,
                enabled = enabled,
                modifier = Modifier.size(20.dp),
                colors = RadioButtonDefaults.colors(
                    selectedColor = TranslationModelSheetColors.Primary,
                    unselectedColor = Color(0xFF98A2B3),
                    disabledColor = Color(0xFFCCD3DE)
                )
            )
        }
    }
}

private object TranslationModelSheetColors {
    val Primary = Color(0xFF0A84FF)
    val TextPrimary = Color(0xFF1A1A2E)
    val TextSecondary = Color(0xFF8B8FA3)
    val Border = Color(0xFFE5E7EB)
    val SelectedSurface = Color(0xFFF8F7FF)
    val Scrim = Color(0x73000000)
}
