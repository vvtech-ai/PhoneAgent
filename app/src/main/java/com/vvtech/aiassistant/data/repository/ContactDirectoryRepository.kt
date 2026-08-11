package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.data.model.ContactAiModelRequest
import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.ContactLookupResultRequest
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.network.NetworkModule

object ContactDirectoryContainer {
    val repository: ContactDirectoryRepository by lazy {
        ContactDirectoryRepository(apiService = NetworkModule.assistantApiService)
    }
}

class ContactDirectoryRepository(
    private val apiService: AssistantApiService
) {

    suspend fun listContacts(userId: String): List<ContactDirectoryEntry> {
        return unwrap(apiService.listContacts(userId))
    }

    suspend fun getContact(phone: String, userId: String): ContactDirectoryEntry {
        return unwrap(apiService.getContact(phone, userId))
    }

    suspend fun upsertContact(request: ContactDirectoryUpsertRequest): ContactDirectoryEntry {
        return unwrap(apiService.upsertContact(request))
    }

    suspend fun deleteContact(phone: String, userId: String) {
        apiService.deleteContact(phone, userId)
    }

    suspend fun aiModelContact(userId: String, callId: String): ContactDirectoryEntry {
        return unwrap(apiService.aiModelContact(ContactAiModelRequest(userId = userId, callId = callId)))
    }

    suspend fun postContactLookupResult(request: ContactLookupResultRequest): AgentChatResponse {
        return unwrap(apiService.postContactLookupResult(request))
    }

    private fun <T> unwrap(response: ApiResponse<T>): T {
        if (response.code != 0) {
            throw IllegalStateException(response.message)
        }
        return response.data ?: throw IllegalStateException("服务端返回了空数据")
    }
}
