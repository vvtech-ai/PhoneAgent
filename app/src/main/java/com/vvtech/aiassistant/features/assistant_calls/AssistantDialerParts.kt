package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Backspace
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Phone
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog

@Composable
internal fun DialerNumberHeader(
    dialNumber: String,
    country: DialCountry,
    onCountryClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().height(80.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier.clickable(onClick = onCountryClick),
            verticalAlignment = Alignment.CenterVertically
        ) {
            DialCountryFlagIcon(country.iso, modifier = Modifier.size(width = 26.dp, height = 18.dp))
            Text(
                country.dialCode,
                modifier = Modifier.padding(start = 5.dp),
                color = Color(0xFF111111),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            )
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = "选择国家或地区",
                tint = Color(0xFF667085),
                modifier = Modifier.padding(horizontal = 5.dp).size(18.dp)
            )
        }
        Box(
            Modifier
                .padding(horizontal = 7.dp)
                .size(width = 1.dp, height = 28.dp)
                .background(Color(0xFFD0D5DD))
        )
        Text(
            text = formatDialInputForDisplay(dialNumber, country.iso).ifBlank { "请输入号码" },
            modifier = Modifier.weight(1f),
            color = if (dialNumber.isBlank()) Color(0xFFB7BAC2) else Color(0xFF111111),
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Clip
        )
    }
}

@Composable
internal fun TranslationLanguageLine(
    translateEnabled: Boolean,
    modelTitle: String,
    myLanguage: String,
    otherLanguage: String,
    onModelClick: () -> Unit,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier.clickable(onClick = onModelClick),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier
                    .size(7.dp)
                    .background(
                        if (translateEnabled) Color(0xFF6C5CE7) else Color(0xFFB7BAC2),
                        CircleShape
                    )
            )
            Text(
                dialerModelDisplayName(modelTitle),
                modifier = Modifier.padding(start = 6.dp),
                color = Color(0xFF344054),
                fontSize = 13.5.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Clip
            )
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = "选择模型",
                tint = Color(0xFF667085),
                modifier = Modifier.size(17.dp)
            )
        }
        Row(
            modifier = Modifier.clickable(onClick = onClick),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val label = if (translateEnabled) {
                "我方 $myLanguage  ⇄  $otherLanguage 对方"
            } else {
                "实时翻译  关"
            }
            Text(
                label,
                color = if (translateEnabled) Color(0xFF30323A) else Color(0xFF8E8E93),
                fontSize = 13.5.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1
            )
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = "设置双方语言",
                tint = Color(0xFF667085),
                modifier = Modifier.size(17.dp)
            )
        }
    }
}

@Composable
internal fun DialerBottomActions(
    translateEnabled: Boolean,
    onClose: () -> Unit,
    onDial: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            Icon(
                Icons.Default.Close,
                contentDescription = "关闭拨号盘",
                tint = Color(0xFF4B4D52),
                modifier = Modifier.size(28.dp).clickable(onClick = onClose)
            )
        }
        Box(
            modifier = Modifier
                .size(64.dp)
                .shadow(
                    14.dp,
                    CircleShape,
                    ambientColor = dialCallColor(translateEnabled).copy(alpha = 0.28f)
                )
                .clip(CircleShape)
                .background(dialCallColor(translateEnabled))
                .clickable(onClick = onDial),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Phone,
                contentDescription = if (translateEnabled) "实时翻译呼叫" else "普通呼叫",
                tint = Color.White,
                modifier = Modifier.size(25.dp)
            )
        }
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
            Icon(
                Icons.Default.Backspace,
                contentDescription = "删除",
                tint = Color(0xFF4B4D52),
                modifier = Modifier.size(28.dp).clickable(onClick = onDelete)
            )
        }
    }
}

private fun dialCallColor(translateEnabled: Boolean): Color =
    if (translateEnabled) Color(0xFF6C5CE7) else Color(0xFF34C759)

private fun dialerModelDisplayName(raw: String): String =
    TranslationProviderUiCatalog.option(raw)?.displayName
        ?: raw.ifBlank { TranslationProviderUiCatalog.displayName(null) }
