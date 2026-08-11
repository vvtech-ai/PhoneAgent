package com.vvtech.aiassistant.data.service

import com.vvtech.aiassistant.core.model.AgentChatApiResponse
import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentConversationInterruptApiResponse
import com.vvtech.aiassistant.core.model.AgentConversationInterruptRequest
import com.vvtech.aiassistant.core.model.AssistantMessageRequest
import com.vvtech.aiassistant.core.model.AssistantSessionApiResponse
import com.vvtech.aiassistant.core.model.CallHandoffRequest
import com.vvtech.aiassistant.core.model.CallMonitorTokenApiResponse
import com.vvtech.aiassistant.core.model.CallMonitorTokenRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusApiResponse
import com.vvtech.aiassistant.core.model.CallSessionStatusRequest
import com.vvtech.aiassistant.core.model.DetailSupplementPromptApiResponse
import com.vvtech.aiassistant.core.model.DocumentParseApiResponse
import com.vvtech.aiassistant.core.model.RealtimeSessionApiResponse
import com.vvtech.aiassistant.core.model.StartRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StartTranslationCallRequest
import com.vvtech.aiassistant.core.model.TextSessionStartRequest
import com.vvtech.aiassistant.core.model.TextTurnRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionApiResponse
import com.vvtech.aiassistant.core.model.StopRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.TranslationCallHangupRequest
import com.vvtech.aiassistant.core.model.TranslationCallStartApiResponse
import com.vvtech.aiassistant.core.model.TranslationCallStatusApiResponse
import com.vvtech.aiassistant.core.model.TranslationCallStatusRequest
import com.vvtech.aiassistant.core.model.TranslationLanguageOverrideRequest
import com.vvtech.aiassistant.core.model.TranslationVoiceCapabilitiesApiResponse
import com.vvtech.aiassistant.core.model.UpdateRealtimeContextApiResponse
import com.vvtech.aiassistant.core.model.UpdateRealtimeContextRequest
import com.vvtech.aiassistant.core.model.VoiceClientDiagnosticApiResponse
import com.vvtech.aiassistant.core.model.VoiceClientDiagnosticRequest
import com.vvtech.aiassistant.core.model.VoiceDialogContextApiResponse
import com.vvtech.aiassistant.core.model.VoiceDialogContextRequest
import com.vvtech.aiassistant.data.model.ContactAiModelRequest
import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.ContactLookupResultRequest
import com.vvtech.aiassistant.data.model.DeviceContactsLookupResultRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityVerifiedMetadataRequest
import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.model.ConversationListItem
import okhttp3.MultipartBody
import okhttp3.ResponseBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.Part
import retrofit2.http.POST
import retrofit2.http.PATCH
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.Streaming
import retrofit2.Response
import com.vvtech.aiassistant.data.homeconfig.HomeConfigDto

interface AssistantApiService {

    @GET("api/home-config/published")
    suspend fun getPublishedHomeConfig(
        @Header("If-None-Match") etag: String? = null
    ): Response<ApiResponse<HomeConfigDto>>

    @GET("api/assistant/session/latest")
    suspend fun loadLatestSession(@Query("userId") userId: String): AssistantSessionApiResponse

    @POST("api/assistant/message")
    suspend fun sendMessage(@Body request: AssistantMessageRequest): AssistantSessionApiResponse

    @POST("api/assistant/text/session/start")
    suspend fun startTextSession(@Body request: TextSessionStartRequest): AssistantSessionApiResponse

    @POST("api/assistant/text/turn")
    suspend fun sendTextTurn(@Body request: TextTurnRequest): AssistantSessionApiResponse

    @GET("api/assistant/detail-supplement/prompts")
    suspend fun loadDetailSupplementPrompts(@Query("sceneType") sceneType: String): DetailSupplementPromptApiResponse

    @POST("api/assistant/voice/dialog/context")
    suspend fun resolveVoiceDialogContext(@Body request: VoiceDialogContextRequest): VoiceDialogContextApiResponse

    @POST("api/assistant/realtime/session/start")
    suspend fun startRealtimeSession(@Body request: StartRealtimeSessionRequest): RealtimeSessionApiResponse

    @POST("api/assistant/realtime/session/stop")
    suspend fun stopRealtimeSession(@Body request: StopRealtimeSessionRequest): StopRealtimeSessionApiResponse

    @POST("api/assistant/realtime/session/context/update")
    suspend fun updateRealtimeContext(@Body request: UpdateRealtimeContextRequest): UpdateRealtimeContextApiResponse

    @POST("api/assistant/realtime/client-diagnostic")
    suspend fun reportVoiceClientDiagnostic(@Body request: VoiceClientDiagnosticRequest): VoiceClientDiagnosticApiResponse

    @POST("api/assistant/realtime/call/session/status")
    suspend fun getCallSessionStatus(@Body request: CallSessionStatusRequest): CallSessionStatusApiResponse

    @POST("api/assistant/realtime/call/handoff/request")
    suspend fun requestCallHandoff(@Body request: CallHandoffRequest): CallSessionStatusApiResponse

    @POST("api/assistant/realtime/call/monitor/token")
    suspend fun createCallMonitorToken(@Body request: CallMonitorTokenRequest): CallMonitorTokenApiResponse

    @POST("api/assistant/realtime/call/handoff/release")
    suspend fun releaseCallHandoff(@Body request: CallHandoffRequest): CallSessionStatusApiResponse

    @POST("api/assistant/realtime/call/hangup")
    suspend fun hangUpCall(@Body request: CallHandoffRequest): CallSessionStatusApiResponse

    @GET("api/assistant/realtime/translation-call/voice-capabilities")
    suspend fun getTranslationVoiceCapabilities(): TranslationVoiceCapabilitiesApiResponse

    @POST("api/assistant/realtime/translation-call/start")
    suspend fun startTranslationCall(@Body request: StartTranslationCallRequest): TranslationCallStartApiResponse

    @POST("api/assistant/realtime/translation-call/status")
    suspend fun getTranslationCallStatus(@Body request: TranslationCallStatusRequest): TranslationCallStatusApiResponse

    @POST("api/assistant/realtime/translation-call/hangup")
    suspend fun hangUpTranslationCall(@Body request: TranslationCallHangupRequest): TranslationCallStatusApiResponse

    @POST("api/assistant/realtime/translation-call/language/override")
    suspend fun overrideTranslationLanguages(@Body request: TranslationLanguageOverrideRequest): TranslationCallStatusApiResponse

    @POST("api/agent/chat")
    suspend fun agentChat(@Body request: AgentChatRequest): AgentChatApiResponse

    @Streaming
    @POST("api/agent/chat/stream")
    suspend fun agentChatStream(@Body request: AgentChatRequest): ResponseBody

    @GET("api/agent/conversations")
    suspend fun getConversations(@Query("userId") userId: String): ApiResponse<List<ConversationListItem>>

    @GET("api/agent/conversations/{sessionId}")
    suspend fun getConversation(@Path("sessionId") sessionId: String): ApiResponse<ConversationDetail>

    @POST("api/agent/conversations/{sessionId}/interrupt")
    suspend fun interruptConversation(
        @Path("sessionId") sessionId: String,
        @Body request: AgentConversationInterruptRequest
    ): AgentConversationInterruptApiResponse

    @Multipart
    @POST("api/documents/parse")
    suspend fun parseDocument(@Part file: MultipartBody.Part): DocumentParseApiResponse

    @GET("api/assistant/user-identity")
    suspend fun getUserIdentity(@Query("userId") userId: String): ApiResponse<UserIdentityPayload>

    @POST("api/assistant/user-identity")
    suspend fun upsertUserIdentity(@Body request: UserIdentityUpsertRequest): ApiResponse<UserIdentityPayload>

    @PATCH("api/assistant/user-identity")
    suspend fun updateVerifiedUserIdentityMetadata(
        @Body request: UserIdentityVerifiedMetadataRequest
    ): ApiResponse<UserIdentityPayload>

    @DELETE("api/assistant/user-identity")
    suspend fun deleteUserIdentity(@Query("userId") userId: String): ApiResponse<UserIdentityPayload>

    @GET("api/assistant/contacts")
    suspend fun listContacts(@Query("userId") userId: String): ApiResponse<List<ContactDirectoryEntry>>

    @GET("api/assistant/contacts/{phone}")
    suspend fun getContact(
        @Path("phone") phone: String,
        @Query("userId") userId: String
    ): ApiResponse<ContactDirectoryEntry>

    @POST("api/assistant/contacts")
    suspend fun upsertContact(@Body request: ContactDirectoryUpsertRequest): ApiResponse<ContactDirectoryEntry>

    @DELETE("api/assistant/contacts/{phone}")
    suspend fun deleteContact(
        @Path("phone") phone: String,
        @Query("userId") userId: String
    ): ApiResponse<Unit>

    @POST("api/assistant/contacts/ai-model")
    suspend fun aiModelContact(@Body request: ContactAiModelRequest): ApiResponse<ContactDirectoryEntry>

    @POST("api/assistant/agent/contact-lookup-result")
    suspend fun postContactLookupResult(@Body request: ContactLookupResultRequest): AgentChatApiResponse

    @POST("api/assistant/agent/device-contacts-lookup-result")
    suspend fun postDeviceContactsLookupResult(@Body request: DeviceContactsLookupResultRequest): AgentChatApiResponse
}
