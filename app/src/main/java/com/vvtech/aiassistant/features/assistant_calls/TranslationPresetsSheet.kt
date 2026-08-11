package com.vvtech.aiassistant.features.assistant_calls

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Switch
import androidx.compose.material.SwitchDefaults
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun TranslationPresetsSheet(
    visible: Boolean,
    translateEnabled: Boolean,
    promptBeforeDial: Boolean,
    myLanguage: String,
    otherLanguage: String,
    onTranslateEnabledChange: (Boolean) -> Unit,
    onPromptBeforeDialChange: (Boolean) -> Unit,
    onMyLanguageChange: (String) -> Unit,
    onOtherLanguageChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onCall: () -> Unit
) {
    if (!visible) return
    var languageTarget by remember(visible) { mutableStateOf<String?>(null) }
    BackHandler(enabled = languageTarget != null) { languageTarget = null }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x52000000))
            .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .widthIn(max = 460.dp)
                .fillMaxWidth()
                .clickable(remember { MutableInteractionSource() }, null) {},
            color = Color(0xFFFCFCFD),
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
        ) {
            Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 28.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "实时翻译通话",
                        modifier = Modifier.weight(1f),
                        color = Color(0xFF111318),
                        fontSize = 19.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Box(Modifier.size(44.dp).clickable(onClick = onDismiss), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Close, "关闭", tint = Color(0xFF667085), modifier = Modifier.size(20.dp))
                    }
                }
                DialSettingSwitchRow(
                    title = "实时翻译",
                    subtitle = "关闭后将作为普通电话呼叫",
                    checked = translateEnabled,
                    onCheckedChange = onTranslateEnabledChange
                )
                DialSettingSwitchRow(
                    title = "拨号前打开本提示",
                    subtitle = null,
                    checked = promptBeforeDial,
                    onCheckedChange = onPromptBeforeDialChange
                )
                Row(
                    Modifier.fillMaxWidth().padding(top = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    DialLanguageCard(
                        "我方",
                        myLanguage,
                        translateEnabled,
                        Modifier.weight(1f)
                    ) { languageTarget = "mine" }
                    DialLanguageCard(
                        "对方",
                        otherLanguage,
                        translateEnabled,
                        Modifier.weight(1f)
                    ) { languageTarget = "other" }
                }
                DialPresetCallButton(
                    text = if (translateEnabled) "实时翻译呼叫" else "普通呼叫",
                    translateEnabled = translateEnabled,
                    onClick = onCall
                )
            }
        }
        languageTarget?.let { target ->
            TranslationLanguagePickerPage(
                title = if (target == "mine") "我的语言" else "对方语言",
                selected = if (target == "mine") myLanguage else otherLanguage,
                onBack = { languageTarget = null },
                onSelect = { language ->
                    if (target == "mine") {
                        onMyLanguageChange(language)
                    } else {
                        onOtherLanguageChange(language)
                    }
                    languageTarget = null
                }
            )
        }
    }
}

@Composable
private fun DialSettingSwitchRow(
    title: String,
    subtitle: String?,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(top = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = Color(0xFF202228), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            subtitle?.let {
                Text(it, color = Color(0xFF8A8F9D), fontSize = 12.sp, modifier = Modifier.padding(top = 2.dp))
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Color(0xFF34C759)
            )
        )
    }
}

@Composable
private fun DialLanguageCard(
    label: String,
    value: String,
    enabled: Boolean,
    modifier: Modifier,
    onClick: () -> Unit
) {
    Column(modifier) {
        Text(
            label,
            modifier = Modifier.fillMaxWidth().padding(bottom = 7.dp),
            color = Color(0xFF30323A),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold
        )
        Surface(
            modifier = Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onClick),
            color = Color(0xFFF8FAFD),
            shape = RoundedCornerShape(14.dp),
            border = BorderStroke(1.dp, Color(0xFFDCE4EF))
        ) {
            Row(
                Modifier.padding(horizontal = 13.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    value,
                    modifier = Modifier.weight(1f),
                    color = if (enabled) Color(0xFF202228) else Color(0xFFB7BAC2),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Icon(
                    Icons.Default.KeyboardArrowRight,
                    contentDescription = null,
                    tint = Color(0xFF98A2B3),
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun DialPresetCallButton(text: String, translateEnabled: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val colors = if (translateEnabled) {
        listOf(Color(0xFF7C6DFF), Color(0xFF6C5CE7))
    } else {
        listOf(Color(0xFF34C759), Color(0xFF28A745))
    }
    val shadowColor = if (translateEnabled) Color(0x426C5CE7) else Color(0x3D34C759)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 18.dp)
            .height(54.dp)
            .shadow(14.dp, shape, ambientColor = shadowColor, spotColor = shadowColor)
            .clip(shape)
            .background(Brush.verticalGradient(colors))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
