package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactSkillOption

@Composable
fun ContactsSkillsReference(scene: String) {
    PhoneFrameWithBackground {
        NativeContactSkillSheet(
            contactName = "合成联系人",
            options = if (scene == "contacts-skills") listOf(
                AssistantContactSkillOption("1", "合成叫醒服务", "请在指定时间联系此人", true, null, "1", null),
                AssistantContactSkillOption("2", "合成用于长标题省略核对的技能", "合成较长的技能说明用于核对正常与放大字号下的两行省略和列表显示效果。", true, null, "2", null)
            ) else emptyList(),
            loading = scene == "contacts-skills-loading",
            onDismiss = {}, onSelect = {}
        )
    }
}
