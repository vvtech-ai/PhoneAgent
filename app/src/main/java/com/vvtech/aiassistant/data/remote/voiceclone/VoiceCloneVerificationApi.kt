package com.vvtech.aiassistant.data.remote.voiceclone

import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

internal interface VoiceCloneVerificationApi {
    @POST("api/account/settings/voice-clone/verification/init")
    suspend fun initialize(
        @Body request: VoiceCloneVerificationInitRequest
    ): ApiResponse<VoiceCloneVerificationInitResponse>

    @POST("api/account/settings/voice-clone/verification/replacement-check")
    suspend fun checkReplacement(
        @Body request: VoiceCloneIdentityReplacementCheckRequest
    ): ApiResponse<VoiceCloneIdentityReplacementCheckResponse>

    @GET("api/account/settings/voice-clone/verification/{attemptId}")
    suspend fun status(
        @Path("attemptId") attemptId: String
    ): ApiResponse<VoiceCloneVerificationStatusResponse>

    @POST("api/account/settings/voice-clone/verification/{attemptId}/client-observation")
    suspend fun reportClientObservation(
        @Path("attemptId") attemptId: String,
        @Body request: VoiceCloneVerificationClientObservationRequest
    ): ApiResponse<VoiceCloneVerificationClientObservationResponse>

    @POST("api/account/settings/voice-clone/verification/{attemptId}/complete")
    suspend fun complete(
        @Path("attemptId") attemptId: String
    ): ApiResponse<VoiceCloneStatusResponse>

    @POST("api/account/settings/voice-clone/verification/{attemptId}/activate")
    suspend fun activate(
        @Path("attemptId") attemptId: String,
        @Body request: VoiceCloneCompletionActivationRequest
    ): ApiResponse<VoiceCloneStatusResponse>

    @POST("api/account/settings/voice-clone/collection")
    suspend fun createCollection(
        @Body request: VoiceCloneCollectionRequest
    ): ApiResponse<VoiceCloneCollectionResponse>
}
