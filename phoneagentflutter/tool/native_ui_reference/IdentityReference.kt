package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.MyIdentityScreen
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.data.model.UserIdentityPayload

/** Synthetic identity only; never save, delete, authenticate or enter clone. */
@Composable
fun IdentityReference(scene: String, onBack: () -> Unit) {
    PhoneFrameWithBackground {
        MyIdentityScreen(
            initial = UserIdentityPayload(
                userId = "synthetic-reference",
                name = if (scene == "identity-empty") "" else "演练用户",
                gender = "不透露", contactPhone = "",
                verificationStatus = if (scene == "identity-verified") "VERIFIED" else "",
                updatedAt = "synthetic"
            ),
            saving = false, loading = scene == "identity-loading",
            error = if (scene == "identity-error") "身份资料加载失败，请重试" else null,
            onBack = onBack, onSave = {}, onDelete = {}, onOpenVoiceModelSettings = {}
        )
    }
}
