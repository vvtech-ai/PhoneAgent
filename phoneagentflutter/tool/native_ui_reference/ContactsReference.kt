package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant.FinalContactRecord
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactsPage
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPage
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageState
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageCallbacks

/** Synthetic authorized records; no contact source, permission or dialer. */
@Composable
fun ContactsReference(scene: String) {
    PhoneFrameWithBackground {
        if (scene.startsWith("contacts-detail")) {
            AssistantContactDetailPage(
                state = AssistantContactDetailPageState(
                    name = "合成联系人", phone = "00000001",
                    hint = "本机通讯录联系人",
                    remark = if (scene == "contacts-detail-saved") "合成备注：请在七点联系。" else "",
                    loading = scene == "contacts-detail-loading", saving = false, error = null
                ),
                callbacks = AssistantContactDetailPageCallbacks(
                    onBack = {}, onCall = {}, onSkillSelected = { false }, onSaveRemark = {}
                )
            )
        } else AssistantContactsPage(
            records = if (scene == "contacts-empty") emptyList() else listOf(
                FinalContactRecord("合成联系人", "00000001", hint = "本机通讯录联系人"),
                FinalContactRecord("合成用于长姓名省略核对的联系人", "00000002", hint = "本机通讯录联系人")
            ),
            onOpenDetail = {}
        )
    }
}
