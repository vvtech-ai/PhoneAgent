package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import com.vvtech.aiassistant.features.assistant_ui.AssistantAiLoadingBubble
import com.vvtech.aiassistant.features.assistant_ui.AssistantBackIconBar
import com.vvtech.aiassistant.features.assistant_ui.AssistantBackTitleBar
import com.vvtech.aiassistant.features.assistant_ui.AssistantSegmentedSelector
import com.vvtech.aiassistant.features.assistant_ui.AssistantSegmentedSelectorItem
import com.vvtech.aiassistant.features.assistant_ui.AssistantFlowTitle
import com.vvtech.aiassistant.features.assistant_ui.AssistantFlowTopBar
import com.vvtech.aiassistant.features.assistant_ui.AssistantTextInputField
import com.vvtech.aiassistant.features.assistant_ui.AssistantMetricCard
import com.vvtech.aiassistant.features.assistant_ui.AssistantScreenTopBar
import com.vvtech.aiassistant.features.assistant_ui.AssistantStopButton
import com.vvtech.aiassistant.features.assistant_ui.AssistantWideButton

@Composable
internal fun FinalScreenTopBar(
    title: String,
    subtitle: String = "",
    trailing: (@Composable () -> Unit)? = null
) {
    AssistantScreenTopBar(title = title, subtitle = subtitle, trailing = trailing)
}

@Composable
internal fun FinalFlowTopBar(
    backLabel: String,
    onBack: () -> Unit,
    onStop: (() -> Unit)? = null
) {
    AssistantFlowTopBar(backLabel = backLabel, onBack = onBack, onStop = onStop)
}

@Composable
internal fun FinalBackTitleBar(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    dark: Boolean = false,
    trailing: (@Composable () -> Unit)? = null
) {
    AssistantBackTitleBar(title = title, onBack = onBack, modifier = modifier, dark = dark, trailing = trailing)
}

@Composable
internal fun FinalBackIconBar(
    onBack: () -> Unit,
    onStop: (() -> Unit)? = null
) {
    AssistantBackIconBar(onBack = onBack, onStop = onStop)
}

@Composable
internal fun FinalStopButton(onClick: () -> Unit) {
    AssistantStopButton(onClick = onClick)
}

@Composable
internal fun FinalFlowTitle(text: String) {
    AssistantFlowTitle(text = text)
}

@Composable
internal fun FinalWideButtonV3(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    AssistantWideButton(
        label = label,
        modifier = modifier,
        enabled = enabled,
        danger = danger,
        onClick = onClick
    )
}

@Composable
internal fun FinalInputFieldV3(
    label: String,
    value: String,
    placeholder: String,
    keyboardType: KeyboardType,
    onValueChange: (String) -> Unit
) {
    AssistantTextInputField(
        label = label,
        value = value,
        placeholder = placeholder,
        keyboardType = keyboardType,
        onValueChange = onValueChange
    )
}

@Composable
internal fun FinalGenderSelectorV3(
    selected: PersonalInfoGender,
    onSelect: (PersonalInfoGender) -> Unit
) {
    AssistantSegmentedSelector(
        label = "性别",
        selected = selected,
        options = PersonalInfoGender.values().map { option ->
            AssistantSegmentedSelectorItem(value = option, label = option.displayLabel())
        },
        onSelect = onSelect
    )
}

@Composable
internal fun FinalAiLoadingBubbleV3(modifier: Modifier = Modifier) {
    AssistantAiLoadingBubble(modifier = modifier)
}

@Composable
internal fun FinalMetricCardV3(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    AssistantMetricCard(label = label, value = value, modifier = modifier)
}
