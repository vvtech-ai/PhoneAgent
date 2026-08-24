package com.vvtech.aiassistant.features.assistant_settings

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.RadioButton
import androidx.compose.material.RadioButtonDefaults
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.features.assistant_i18n.appText

internal data class AssistantSipAccountSettingsState(
    val selectedDomesticAccountId: String,
    val selectedInternationalAccountId: String
)

internal data class AssistantSipAccountSettingsCallbacks(
    val onBack: () -> Unit,
    val onSelectDomesticAccount: (String) -> Unit,
    val onSelectInternationalAccount: (String) -> Unit
)

@Composable
internal fun AssistantSipAccountSettingsPage(
    state: AssistantSipAccountSettingsState,
    callbacks: AssistantSipAccountSettingsCallbacks,
    appLanguage: AppLanguage = AppLanguage.SimplifiedChinese
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "SIP账号设置".appText(appLanguage, "SIP Account Settings"), onBack = callbacks.onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 24.dp)
        ) {
            item {
                SipAccountSectionTitle(
                    title = "国内账号".appText(appLanguage, "Domestic Account"),
                    description = "中国大陆号码使用所选账号呼出".appText(
                        appLanguage,
                        "Mainland China numbers use the selected account"
                    )
                )
            }
            items(AssistantDomesticSipAccountOptions, key = { "domestic-${it.id}" }) { option ->
                SipAccountOptionRow(
                    option = option,
                    selected = option.id == state.selectedDomesticAccountId,
                    onSelect = callbacks.onSelectDomesticAccount,
                    appLanguage = appLanguage
                )
            }
            item {
                SipAccountSectionTitle(
                    title = "国际账号".appText(appLanguage, "International Account"),
                    description = "国际 SIP 线路使用所选账号呼出".appText(
                        appLanguage,
                        "International SIP lines use the selected account"
                    )
                )
            }
            items(AssistantInternationalSipAccountOptions, key = { "international-${it.id}" }) { option ->
                SipAccountOptionRow(
                    option = option,
                    selected = option.id == state.selectedInternationalAccountId,
                    onSelect = callbacks.onSelectInternationalAccount,
                    appLanguage = appLanguage
                )
            }
        }
    }
}

@Composable
private fun SipAccountSectionTitle(title: String, description: String) {
    Column(modifier = Modifier.padding(start = 4.dp, top = 14.dp, end = 4.dp, bottom = 10.dp)) {
        Text(
            text = title,
            color = Color(0xFF344054),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = description,
            modifier = Modifier.padding(top = 4.dp),
            color = Color(0xFF667085),
            fontSize = 12.sp
        )
    }
}

@Composable
private fun SipAccountOptionRow(
    option: AssistantSipAccountOption,
    selected: Boolean,
    onSelect: (String) -> Unit,
    appLanguage: AppLanguage
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .clickable(enabled = !selected) { onSelect(option.id) },
        color = Color.White.copy(alpha = 0.84f),
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(
            width = 1.dp,
            color = if (selected) Color(0x660A84FF) else Color.White.copy(alpha = 0.78f)
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, top = 10.dp, end = 10.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = option.label(appLanguage),
                modifier = Modifier.weight(1f),
                color = Color(0xFF111111),
                fontSize = 16.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium
            )
            RadioButton(
                selected = selected,
                onClick = { if (!selected) onSelect(option.id) },
                colors = RadioButtonDefaults.colors(
                    selectedColor = Color(0xFF0A84FF),
                    unselectedColor = Color(0xFF98A2B3)
                )
            )
        }
    }
}
