package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentConversationInterruptRequest
import com.vvtech.aiassistant.core.model.AgentConversationInterruptResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.AssistantMessageRequest
import com.vvtech.aiassistant.core.model.CallHandoffRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.RealtimeSessionResponse
import com.vvtech.aiassistant.core.model.StartRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StartTranslationCallRequest
import com.vvtech.aiassistant.core.model.TextSessionStartRequest
import com.vvtech.aiassistant.core.model.TextTurnRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionResponse
import com.vvtech.aiassistant.core.model.TranslationCallHangupRequest
import com.vvtech.aiassistant.core.model.TranslationCallStartResponse
import com.vvtech.aiassistant.core.model.TranslationCallStatusRequest
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.core.model.TranslationLanguageOverrideRequest
import com.vvtech.aiassistant.core.model.TranslationVoiceCapabilitiesResponse
import com.vvtech.aiassistant.core.model.UpdateRealtimeContextRequest
import com.vvtech.aiassistant.core.model.UpdateRealtimeContextResponse
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.AssistantSessionHistoryResponse
import com.vvtech.aiassistant.core.model.VoiceDialogContextRequest
import com.vvtech.aiassistant.core.model.VoiceDialogContextResponse
import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.ContactLookupResultRequest
import com.vvtech.aiassistant.data.model.DeviceContactsLookupResultRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityVerifiedMetadataRequest
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.network.NetworkModule
import kotlinx.coroutines.flow.Flow
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

object AssistantContainer {
    val repository: AssistantRepository by lazy {
        AssistantRepository(
            apiService = NetworkModule.assistantApiService,
            streamingApiService = NetworkModule.streamingAssistantApiService
        )
    }
}

class AssistantRepository(
    private val apiService: AssistantApiService,
    private val streamingApiService: AssistantApiService = apiService
) {
    private val agentStreamRemoteDataSource = AgentStreamRemoteDataSource(
        streamingApiService = streamingApiService
    )

    suspend fun loadLatestSession(userId: String): AssistantSessionResponse {
        return unwrap(apiService.loadLatestSession(userId))
    }

    suspend fun loadSessionHistory(userId: String): AssistantSessionHistoryResponse {
        return AssistantSessionHistoryResponse(tasks = emptyList())
    }

    suspend fun sendMessage(request: AssistantMessageRequest): AssistantSessionResponse {
        return unwrap(apiService.sendMessage(request))
    }

    suspend fun startTextSession(request: TextSessionStartRequest): AssistantSessionResponse {
        return unwrap(apiService.startTextSession(request))
    }

    suspend fun sendTextTurn(request: TextTurnRequest): AssistantSessionResponse {
        return unwrap(apiService.sendTextTurn(request))
    }

    suspend fun loadDetailSupplementPrompts(sceneType: String): DetailSupplementPromptResponse {
        return unwrap(apiService.loadDetailSupplementPrompts(sceneType))
    }

    suspend fun resolveVoiceDialogContext(request: VoiceDialogContextRequest): VoiceDialogContextResponse {
        return unwrap(apiService.resolveVoiceDialogContext(request))
    }

    suspend fun startRealtimeSession(request: StartRealtimeSessionRequest): RealtimeSessionResponse {
        return unwrap(apiService.startRealtimeSession(request))
    }

    suspend fun stopRealtimeSession(request: StopRealtimeSessionRequest): StopRealtimeSessionResponse {
        return unwrap(apiService.stopRealtimeSession(request))
    }

    suspend fun updateRealtimeContext(request: UpdateRealtimeContextRequest): UpdateRealtimeContextResponse {
        return unwrap(apiService.updateRealtimeContext(request))
    }

    suspend fun getCallSessionStatus(request: CallSessionStatusRequest): CallSessionStatusResponse {
        return unwrap(apiService.getCallSessionStatus(request))
    }

    suspend fun requestCallHandoff(request: CallHandoffRequest): CallSessionStatusResponse {
        return unwrap(apiService.requestCallHandoff(request))
    }

    suspend fun createCallMonitorToken(
        request: com.vvtech.aiassistant.core.model.CallMonitorTokenRequest
    ): com.vvtech.aiassistant.core.model.CallMonitorTokenResponse {
        return unwrap(apiService.createCallMonitorToken(request))
    }

    suspend fun releaseCallHandoff(request: CallHandoffRequest): CallSessionStatusResponse {
        return unwrap(apiService.releaseCallHandoff(request))
    }

    suspend fun hangUpCall(request: CallHandoffRequest): CallSessionStatusResponse {
        return unwrap(apiService.hangUpCall(request))
    }

    suspend fun getTranslationVoiceCapabilities(): TranslationVoiceCapabilitiesResponse {
        return unwrap(apiService.getTranslationVoiceCapabilities())
    }

    suspend fun startTranslationCall(request: StartTranslationCallRequest): TranslationCallStartResponse {
        return unwrap(apiService.startTranslationCall(request))
    }

    suspend fun getTranslationCallStatus(request: TranslationCallStatusRequest): TranslationCallStatusResponse {
        return unwrap(apiService.getTranslationCallStatus(request))
    }

    suspend fun hangUpTranslationCall(request: TranslationCallHangupRequest): TranslationCallStatusResponse {
        return unwrap(apiService.hangUpTranslationCall(request))
    }

    suspend fun overrideTranslationLanguages(request: TranslationLanguageOverrideRequest): TranslationCallStatusResponse {
        return unwrap(apiService.overrideTranslationLanguages(request))
    }

    suspend fun agentChat(request: AgentChatRequest): AgentChatResponse {
        return unwrap(apiService.agentChat(request))
    }

    suspend fun parseDocument(fileName: String, mimeType: String?, bytes: ByteArray): DocumentParseResult {
        val requestBody = bytes.toRequestBody(mimeType?.toMediaTypeOrNull())
        val part = MultipartBody.Part.createFormData("file", fileName, requestBody)
        return unwrap(apiService.parseDocument(part))
    }

    suspend fun getUserIdentity(userId: String): UserIdentityPayload {
        return unwrap(apiService.getUserIdentity(userId))
    }

    suspend fun upsertUserIdentity(request: UserIdentityUpsertRequest): UserIdentityPayload {
        return unwrap(apiService.upsertUserIdentity(request))
    }

    suspend fun updateVerifiedUserIdentityMetadata(
        request: UserIdentityVerifiedMetadataRequest
    ): UserIdentityPayload {
        return unwrap(apiService.updateVerifiedUserIdentityMetadata(request))
    }

    suspend fun deleteUserIdentity(userId: String): UserIdentityPayload {
        return unwrap(apiService.deleteUserIdentity(userId))
    }

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

    suspend fun postContactLookupResult(request: ContactLookupResultRequest): AgentChatResponse {
        return unwrap(apiService.postContactLookupResult(request))
    }

    suspend fun postDeviceContactsLookupResult(request: DeviceContactsLookupResultRequest): AgentChatResponse {
        return unwrap(apiService.postDeviceContactsLookupResult(request))
    }

    suspend fun getConversations(userId: String): List<com.vvtech.aiassistant.model.ConversationListItem> {
        return unwrap(apiService.getConversations(userId))
    }

    suspend fun getConversation(sessionId: String): com.vvtech.aiassistant.model.ConversationDetail {
        return unwrap(apiService.getConversation(sessionId))
    }

    suspend fun interruptConversation(
        sessionId: String,
        userId: String,
        reason: String? = null
    ): AgentConversationInterruptResponse {
        return unwrap(
            apiService.interruptConversation(
                sessionId,
                AgentConversationInterruptRequest(userId = userId, reason = reason)
            )
        )
    }

    fun agentChatStream(request: AgentChatRequest): Flow<AgentStreamEvent> {
        return agentStreamRemoteDataSource.stream(request)
    }

    private fun <T> unwrap(response: com.vvtech.aiassistant.model.ApiResponse<T>): T {
        if (response.code != 0) {
            throw IllegalStateException(response.message)
        }
        return response.data ?: throw IllegalStateException("服务端返回了空数据")
    }
}
