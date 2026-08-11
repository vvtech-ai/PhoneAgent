package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import java.util.Locale

internal enum class UserIdentityDisplayStatus {
    EMPTY,
    FILLED,
    VERIFIED;

    companion object {
        fun from(payload: UserIdentityPayload?): UserIdentityDisplayStatus {
            if (payload?.name.isNullOrBlank()) return EMPTY
            return when (payload?.verificationStatus?.trim()?.uppercase(Locale.ROOT)) {
                VERIFIED.name -> VERIFIED
                else -> FILLED
            }
        }
    }
}
