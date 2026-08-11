package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneIdentityPrefill

internal suspend fun loadVoiceCloneIdentityPrefill(
    accountId: String,
    loadIdentity: suspend (String) -> UserIdentityPayload
): VoiceCloneIdentityPrefill? =
    accountId
        .takeIf(String::isNotBlank)
        ?.let { loadIdentity(it) }
        ?.let { identity ->
            VoiceCloneIdentityPrefill(
                name = identity.name.orEmpty(),
                verified = identity.verificationStatus.equals("VERIFIED", ignoreCase = true)
            )
        }
