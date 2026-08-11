package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPage
import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPageArgs
@Composable
internal fun FinalSettingsSectionTitle(
    text: String,
    first: Boolean = false
) {
    Text(
        text = text,
        modifier = Modifier.padding(top = if (first) 16.dp else 14.dp, bottom = 10.dp, start = 4.dp),
        color = Color(0xFF111111),
        fontSize = 17.sp,
        fontWeight = FontWeight.ExtraBold,
        letterSpacing = 0.sp
    )
}

@Composable
internal fun FinalDeveloperToolsPageV3(args: AssistantDeveloperToolsPageArgs) {
    AssistantDeveloperToolsPage(args)
}

@Composable
internal fun FinalDeveloperActionRow(
    title: String,
    subtitle: String,
    actionText: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = Color(0xFF111111), fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, modifier = Modifier.padding(top = 3.dp), color = Color(0xFF6E6E73), fontSize = 12.sp)
        }
        Surface(
            modifier = Modifier.clickable(onClick = onClick),
            color = Color(0xFFF2F4F7),
            shape = RoundedCornerShape(9.dp),
            elevation = 0.dp
        ) {
            Text(
                text = actionText,
                modifier = Modifier.padding(horizontal = 13.dp, vertical = 8.dp),
                color = Color(0xFF111111),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
internal fun FinalDeveloperToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = Color(0xFF111111), fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, modifier = Modifier.padding(top = 3.dp), color = Color(0xFF6E6E73), fontSize = 12.sp)
        }
        Surface(
            modifier = Modifier
                .size(width = 44.dp, height = 24.dp)
                .clickable { onCheckedChange(!checked) },
            color = if (checked) Color(0xFF6C5CE7) else Color(0xFFD1D5DB),
            shape = RoundedCornerShape(12.dp),
            elevation = 0.dp
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .align(if (checked) Alignment.CenterEnd else Alignment.CenterStart)
                        .padding(2.dp)
                        .background(Color.White, RoundedCornerShape(10.dp))
                )
            }
        }
    }
}

@Composable
internal fun FinalDeveloperModeButtonV3(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        color = if (selected) Color(0xFFEFF6FF) else Color.White.copy(alpha = 0.92f),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(
            1.dp,
            if (selected) Color(0x800A84FF) else Color(0x143C3C43)
        ),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 11.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = if (selected) Color(0xFF0A84FF) else Color(0xFF6E6E73),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
internal fun FinalSettingCardV3(
    title: String,
    subtitle: String,
    value: String,
    onClick: () -> Unit
) {
    val safeTitle = sanitizeTranslationSettingsUiDisplayTextFinal(title)
    val safeSubtitle = sanitizeTranslationSettingsUiDisplayTextFinal(subtitle)
    val safeValue = sanitizeTranslationSettingsUiDisplayTextFinal(value)
    val displayTitle = safeTitle
    val displayValue = safeValue
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color(0x14101114),
                spotColor = Color(0x14101114)
            )
            .clickable(onClick = onClick),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = displayTitle,
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = safeSubtitle,
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
            }
            Text(
                text = displayValue,
                modifier = Modifier.padding(start = 12.dp),
                color = Color(0xFF6E6E73),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
