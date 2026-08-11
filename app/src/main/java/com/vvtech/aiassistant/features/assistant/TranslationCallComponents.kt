package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
@Composable
internal fun TranslationTopBar(title: String, onBack: () -> Unit, dark: Boolean = false) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            modifier = Modifier.clickable(onClick = onBack),
            shape = CircleShape,
            color = if (dark) Color.White.copy(alpha = 0.12f) else Color.White
        ) {
            Box(modifier = Modifier.padding(10.dp)) {
                Icon(
                    Icons.Outlined.ArrowBack,
                    contentDescription = null,
                    tint = if (dark) Color.White else Color(0xFF111827)
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Text(
            text = title,
            color = if (dark) Color.White else Color(0xFF111827),
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
internal fun TranslationSectionCard(
    containerColor: Color = Color.White,
    content: @Composable () -> Unit
) {
    Surface(color = containerColor, shape = RoundedCornerShape(24.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp)
        ) {
            content()
        }
    }
}

@Composable
internal fun TranslationTextField(
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFFF8FAFC),
        shape = RoundedCornerShape(18.dp)
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Color(0xFF111827),
                fontSize = 16.sp
            ),
            decorationBox = { inner ->
                if (value.isBlank()) {
                    Text(placeholder, color = Color(0xFF98A2B3), fontSize = 15.sp)
                }
                inner()
            }
        )
    }
}

@Composable
internal fun TranslationSegmentedRow(
    options: List<Pair<String, String>>,
    selected: String,
    onSelected: (String) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        options.forEach { (key, label) ->
            val isSelected = selected == key
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelected(key) },
                color = if (isSelected) Color(0xFF111827) else Color(0xFFF4F6F8),
                shape = RoundedCornerShape(18.dp)
            ) {
                Text(
                    text = label,
                    modifier = Modifier.padding(vertical = 12.dp),
                    textAlign = TextAlign.Center,
                    color = if (isSelected) Color.White else Color(0xFF344054),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
internal fun TranslationLanguagePicker(
    selected: String,
    onSelected: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TranslationProviderLanguageChoices.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { option ->
                    TranslationChip(
                        label = option.label,
                        selected = selected.equals(option.code, ignoreCase = true),
                        onClick = { onSelected(option.code) }
                    )
                }
            }
        }
    }
}

@Composable
internal fun TranslationChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        color = if (selected) Color(0xFF111827) else Color.White,
        shape = RoundedCornerShape(999.dp),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (selected) Color(0xFF111827) else Color(0xFFD0D5DD)
        )
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            color = if (selected) Color.White else Color(0xFF344054),
            fontSize = 13.sp
        )
    }
}

@Composable
internal fun TranslationPrimaryButton(
    label: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = if (enabled) Color(0xFF16A34A) else Color(0xFF98A2B3),
        shape = RoundedCornerShape(22.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = enabled, onClick = onClick)
                .padding(vertical = 16.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.Phone, contentDescription = null, tint = Color.White)
                Spacer(Modifier.width(8.dp))
                Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
internal fun TranslationGhostButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(20.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFD0D5DD))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(vertical = 14.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(label, color = Color(0xFF344054), fontSize = 15.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
internal fun TranslationStatusPill(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = Color(0xFFD0D5DD), fontSize = 13.sp)
        Text(value.ifBlank { "--" }, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
internal fun TranslationStatusRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 14.sp, color = Color(0xFF667085))
        Text(value.ifBlank { "--" }, fontSize = 14.sp, color = Color(0xFF111827), fontWeight = FontWeight.Medium)
    }
}
