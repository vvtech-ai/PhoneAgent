package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal data class AssistantSegmentedSelectorItem<T>(
    val value: T,
    val label: String
)

@Composable
internal fun AssistantWideButton(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    val backgroundBrush = when {
        danger && enabled -> Brush.verticalGradient(listOf(Color(0xFFFF5B57), Color(0xFFFF3B30)))
        danger && !enabled -> Brush.verticalGradient(listOf(Color(0xFFF8DAD8), Color(0xFFF4CCCA)))
        enabled -> Brush.verticalGradient(
            listOf(
                Color.White.copy(alpha = 0.84f),
                Color.White.copy(alpha = 0.84f)
            )
        )
        else -> Brush.verticalGradient(listOf(Color(0xFFF1F4F8), Color(0xFFEDF2F8)))
    }
    val borderColor = when {
        danger -> Color.Transparent
        enabled -> Color(0x143C3C43)
        else -> Color(0xFFDCE4EE)
    }
    val labelColor = when {
        danger && enabled -> Color.White
        danger && !enabled -> Color(0xFFFBECEC)
        enabled -> Color(0xFF111111)
        else -> Color(0xFF9FA9B8)
    }

    Surface(
        modifier = modifier
            .heightIn(min = 52.dp)
            .clickable(enabled = enabled, onClick = onClick),
        color = Color.Transparent,
        shape = RoundedCornerShape(20.dp),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = backgroundBrush,
                    shape = RoundedCornerShape(20.dp)
                )
                .border(
                    width = if (danger) 0.dp else 1.dp,
                    color = borderColor,
                    shape = RoundedCornerShape(20.dp)
                )
                .padding(horizontal = 16.dp, vertical = 15.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = labelColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
internal fun AssistantTextInputField(
    label: String,
    value: String,
    placeholder: String,
    keyboardType: KeyboardType,
    onValueChange: (String) -> Unit
) {
    Text(
        text = label,
        modifier = Modifier.padding(top = 10.dp),
        color = Color(0xFF6E6E73),
        fontSize = 12.sp,
        fontWeight = FontWeight.ExtraBold
    )
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        color = Color.White.copy(alpha = 0.94f),
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            textStyle = TextStyle(
                color = Color(0xFF111111),
                fontSize = 15.sp
            ),
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                imeAction = ImeAction.Done
            ),
            decorationBox = { inner ->
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        color = Color(0xFF98A2B3),
                        fontSize = 14.sp
                    )
                }
                inner()
            }
        )
    }
}

@Composable
internal fun <T> AssistantSegmentedSelector(
    label: String,
    selected: T,
    options: List<AssistantSegmentedSelectorItem<T>>,
    onSelect: (T) -> Unit
) {
    Text(
        text = label,
        modifier = Modifier.padding(top = 14.dp),
        color = Color(0xFF6E6E73),
        fontSize = 12.sp,
        fontWeight = FontWeight.ExtraBold
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        options.forEach { option ->
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelect(option.value) },
                color = if (option.value == selected) Color(0xFFF4F9FF) else Color.White.copy(alpha = 0.90f),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(
                    1.dp,
                    if (option.value == selected) Color(0x4F007AFF) else Color(0x143C3C43)
                ),
                elevation = 0.dp
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = option.label,
                        color = Color(0xFF111111),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}
