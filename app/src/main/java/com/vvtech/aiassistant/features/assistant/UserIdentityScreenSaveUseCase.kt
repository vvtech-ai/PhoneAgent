package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityVerifiedMetadataRequest
import com.vvtech.aiassistant.data.repository.AssistantRepository

internal suspend fun saveUserIdentityForScreen(
    repository: AssistantRepository,
    currentIdentity: UserIdentityPayload?,
    request: UserIdentityUpsertRequest,
    userId: String
): UserIdentityPayload {
    return if (UserIdentityDisplayStatus.from(currentIdentity) == UserIdentityDisplayStatus.VERIFIED) {
        repository.updateVerifiedUserIdentityMetadata(
            UserIdentityVerifiedMetadataRequest(
                userId = userId,
                gender = request.gender,
                contactPhone = request.contactPhone
            )
        )
    } else {
        repository.upsertUserIdentity(request.copy(userId = userId))
    }
}

internal fun shouldReturnToSettingsAfterIdentitySave(
    currentIdentity: UserIdentityPayload?
): Boolean = UserIdentityDisplayStatus.from(currentIdentity) != UserIdentityDisplayStatus.EMPTY
