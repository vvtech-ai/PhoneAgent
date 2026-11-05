package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactRemarkEditor

/** Synthetic editor display only; all save/dismiss callbacks are empty. */
@Composable
fun ContactsRemarkReference(scene: String) {
    PhoneFrameWithBackground {
        AssistantContactRemarkEditor(
            initialRemark = if (scene == "contacts-remark") "" else "合成备注：请在七点联系。",
            saving = scene == "contacts-remark-busy",
            error = if (scene == "contacts-remark-error") "合成保存失败，请稍后重试" else null,
            onDismiss = {},
            onSave = {}
        )
    }
}
