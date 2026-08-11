package com.vvtech.aiassistant.network

import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.AppLogUploadResponse
import com.vvtech.aiassistant.model.AssistantCallHistoryItem
import com.vvtech.aiassistant.model.CallTaskRequest
import com.vvtech.aiassistant.model.CallTaskResponse
import com.vvtech.aiassistant.model.ClientSipLeaseReleaseRequest
import com.vvtech.aiassistant.model.ClientSipLeaseReleaseResponse
import com.vvtech.aiassistant.model.ClientSipLeaseRequest
import com.vvtech.aiassistant.model.ClientSipLeaseResponse
import com.vvtech.aiassistant.model.CreateTaskRequest
import com.vvtech.aiassistant.model.OutboundNumberSettingsResponse
import com.vvtech.aiassistant.model.OtaVersionCheckRequest
import com.vvtech.aiassistant.model.OtaVersionCheckResponse
import com.vvtech.aiassistant.model.RealtimeCallModelLatencyResponse
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse
import com.vvtech.aiassistant.model.RestaurantListResponse
import com.vvtech.aiassistant.model.SelectRestaurantRequest
import com.vvtech.aiassistant.model.SmsLoginRequest
import com.vvtech.aiassistant.model.SmsLoginResponse
import com.vvtech.aiassistant.model.SmsLoginSendCodeRequest
import com.vvtech.aiassistant.model.SmsLoginSendCodeResponse
import com.vvtech.aiassistant.model.TaskActionResponse
import com.vvtech.aiassistant.model.TaskChatRequest
import com.vvtech.aiassistant.model.TaskConfirmRequest
import com.vvtech.aiassistant.model.TaskConfirmResponse
import com.vvtech.aiassistant.model.TaskConversationResponse
import com.vvtech.aiassistant.model.TaskDetailResponse
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.UpdateRealtimeCallProviderRequest
import com.vvtech.aiassistant.model.UpdateRealtimeCallVoiceRequest
import com.vvtech.aiassistant.model.UpdateRealtimeTranslationProviderRequest
import com.vvtech.aiassistant.model.UpdateOutboundNumberRequest
import com.vvtech.aiassistant.model.VoiceCloneScriptsResponse
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.model.VoiceCloneUploadRequest
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Multipart
import retrofit2.http.Part
import retrofit2.http.PUT
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface TaskApiService {

    @POST("api/task/create")
    suspend fun createTask(@Body request: CreateTaskRequest): ApiResponse<TaskConversationResponse>

    @POST("api/task/chat")
    suspend fun chat(@Body request: TaskChatRequest): ApiResponse<TaskConversationResponse>

    @POST("api/task/confirm")
    suspend fun confirm(@Body request: TaskConfirmRequest): ApiResponse<TaskConfirmResponse>

    @GET("api/task/restaurants")
    suspend fun getRestaurants(@Query("taskId") taskId: String): ApiResponse<RestaurantListResponse>

    @POST("api/task/selectRestaurant")
    suspend fun selectRestaurant(@Body request: SelectRestaurantRequest): ApiResponse<TaskActionResponse>

    @POST("api/task/call")
    suspend fun callTask(@Body request: CallTaskRequest): ApiResponse<CallTaskResponse>

    @GET("api/task/detail/{taskId}")
    suspend fun getTaskDetail(@Path("taskId") taskId: String): ApiResponse<TaskDetailResponse>

    @GET("api/task/list")
    suspend fun listTasks(@Query("userId") userId: String? = null): ApiResponse<List<TaskListItem>>

    @GET("api/task/call-history")
    suspend fun listCallHistory(@Query("userId") userId: String? = null): ApiResponse<List<AssistantCallHistoryItem>>

    @POST("api/client-sip/leases")
    suspend fun acquireClientSipLease(
        @Body request: ClientSipLeaseRequest
    ): ApiResponse<ClientSipLeaseResponse>

    @POST("api/client-sip/leases/{leaseId}/release")
    suspend fun releaseClientSipLease(
        @Path("leaseId") leaseId: String,
        @Body request: ClientSipLeaseReleaseRequest
    ): ApiResponse<ClientSipLeaseReleaseResponse>

    @POST("api/auth/sms/send-code")
    suspend fun sendSmsLoginCode(
        @Body request: SmsLoginSendCodeRequest
    ): ApiResponse<SmsLoginSendCodeResponse>

    @POST("api/auth/sms/login")
    suspend fun loginWithSmsCode(
        @Body request: SmsLoginRequest
    ): ApiResponse<SmsLoginResponse>

    @POST("api/auth/session/logout")
    suspend fun logoutAppSession(
        @Header("Authorization") authorization: String
    ): ApiResponse<Unit>

    @GET("api/account/settings/outbound-number")
    suspend fun getOutboundNumberSettings(): ApiResponse<OutboundNumberSettingsResponse>

    @POST("api/account/settings/outbound-number")
    suspend fun updateOutboundNumberSettings(
        @Body request: UpdateOutboundNumberRequest
    ): ApiResponse<OutboundNumberSettingsResponse>

    @DELETE("api/account/settings/outbound-number")
    suspend fun deleteOutboundNumberSettings(): ApiResponse<OutboundNumberSettingsResponse>

    @GET("api/account/settings/realtime-call-provider")
    suspend fun getRealtimeCallProviderSettings(): ApiResponse<RealtimeCallProviderResponse>

    @GET("api/assistant/realtime/call-models/latency")
    suspend fun getRealtimeCallModelLatencies(
        @Query("refresh") refresh: Boolean = false
    ): ApiResponse<RealtimeCallModelLatencyResponse>

    @PUT("api/account/settings/realtime-call-provider")
    suspend fun updateRealtimeCallProviderSettings(
        @Body request: UpdateRealtimeCallProviderRequest
    ): ApiResponse<RealtimeCallProviderResponse>

    @GET("api/account/settings/realtime-call-voice")
    suspend fun getRealtimeCallVoiceSettings(): ApiResponse<RealtimeCallVoiceResponse>

    @PUT("api/account/settings/realtime-call-voice")
    suspend fun updateRealtimeCallVoiceSettings(
        @Body request: UpdateRealtimeCallVoiceRequest
    ): ApiResponse<RealtimeCallVoiceResponse>

    @GET("api/account/settings/realtime-translation-provider")
    suspend fun getRealtimeTranslationProviderSettings(): ApiResponse<RealtimeTranslationProviderResponse>

    @PUT("api/account/settings/realtime-translation-provider")
    suspend fun updateRealtimeTranslationProviderSettings(
        @Body request: UpdateRealtimeTranslationProviderRequest
    ): ApiResponse<RealtimeTranslationProviderResponse>

    @POST("api/ota/check")
    suspend fun checkAppVersion(
        @Body request: OtaVersionCheckRequest
    ): ApiResponse<OtaVersionCheckResponse>

    @Multipart
    @POST("api/logs/upload")
    suspend fun uploadAppLogs(
        @Part file: MultipartBody.Part,
        @Part("accountId") accountId: RequestBody,
        @Part("deviceInfo") deviceInfo: RequestBody
    ): ApiResponse<AppLogUploadResponse>

    @GET("api/account/settings/voice-clone")
    suspend fun getVoiceCloneStatus(): ApiResponse<VoiceCloneStatusResponse>

    @GET("api/account/settings/voice-clone/scripts")
    suspend fun getVoiceCloneScripts(): ApiResponse<VoiceCloneScriptsResponse>

    @POST("api/account/settings/voice-clone/upload")
    suspend fun uploadVoiceCloneSamples(
        @Body request: VoiceCloneUploadRequest
    ): ApiResponse<VoiceCloneStatusResponse>

    @POST("api/account/settings/voice-clone/activate")
    suspend fun activateVoiceClone(): ApiResponse<VoiceCloneStatusResponse>

    @POST("api/account/settings/voice-clone/deactivate")
    suspend fun deactivateVoiceClone(): ApiResponse<VoiceCloneStatusResponse>
}
