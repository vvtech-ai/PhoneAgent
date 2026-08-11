package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBackIosNew
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private data class DialLanguageOption(val name: String, val nativeLabel: String)

private val DialLanguages = listOf(
    DialLanguageOption("中文", "中文（中国）"),
    DialLanguageOption("英文", "English"),
    DialLanguageOption("日语", "日本語（日本）"),
    DialLanguageOption("韩语", "한국어（한국）"),
    DialLanguageOption("法语", "Français（France）"),
    DialLanguageOption("德语", "Deutsch（Deutschland）"),
    DialLanguageOption("西班牙语", "Español（España）")
)

@Composable
internal fun TranslationLanguagePickerPage(
    title: String,
    selected: String,
    onBack: () -> Unit,
    onSelect: (String) -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Color(0xFFF8F9FC))
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Row(
            Modifier.fillMaxWidth().padding(start = 10.dp, end = 20.dp, top = 18.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier.size(42.dp).clickable(onClick = onBack),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.ArrowBackIosNew,
                    contentDescription = "返回",
                    tint = Color(0xFF111318),
                    modifier = Modifier.size(19.dp)
                )
            }
            Text(title, color = Color(0xFF111318), fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(Modifier.fillMaxSize()) {
            items(DialLanguages, key = { it.name }) { language ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(language.name) }
                        .padding(horizontal = 22.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        language.name,
                        modifier = Modifier.weight(1f),
                        color = Color(0xFF202228),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(language.nativeLabel, color = Color(0xFF8A8F9D), fontSize = 13.sp)
                    Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) {
                        if (language.name == selected) {
                            Icon(
                                Icons.Default.Check,
                                contentDescription = "已选择",
                                tint = Color(0xFF1687F8),
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
