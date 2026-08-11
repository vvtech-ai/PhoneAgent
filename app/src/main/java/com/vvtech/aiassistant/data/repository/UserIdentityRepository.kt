package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityVerifiedMetadataRequest
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.network.NetworkModule

object UserIdentityContainer {
    val repository: UserIdentityRepository by lazy {
        UserIdentityRepository(apiService = NetworkModule.assistantApiService)
    }
}

class UserIdentityRepository(
    private val apiService: AssistantApiService
) {

    suspend fun getUserIdentity(userId: String): UserIdentityPayload {
        return unwrap(apiService.getUserIdentity(userId))
    }

    suspend fun upsertUserIdentity(request: UserIdentityUpsertRequest): UserIdentityPayload {
        return unwrap(apiService.upsertUserIdentity(request))
    }

    suspend fun updateVerifiedMetadata(
        request: UserIdentityVerifiedMetadataRequest
    ): UserIdentityPayload {
        return unwrap(apiService.updateVerifiedUserIdentityMetadata(request))
    }

    suspend fun deleteUserIdentity(userId: String): UserIdentityPayload {
        return unwrap(apiService.deleteUserIdentity(userId))
    }

    private fun <T> unwrap(response: ApiResponse<T>): T {
        if (response.code != 0) {
            throw IllegalStateException(response.message)
        }
        return response.data ?: throw IllegalStateException("服务端返回了空数据")
    }
}
