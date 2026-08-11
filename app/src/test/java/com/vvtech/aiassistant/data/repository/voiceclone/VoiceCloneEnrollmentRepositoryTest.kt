package com.vvtech.aiassistant.data.repository.voiceclone

import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCollectionRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCollectionResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCompletionActivationRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationApi
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationInitRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationInitResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationClientObservationRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationClientObservationResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationStatusResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneIdentityReplacementCheckRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneIdentityReplacementCheckResponse
import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import kotlinx.coroutines.runBlocking
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response

class VoiceCloneEnrollmentRepositoryTest {

    @Test
    fun `activation binds improvement consent to the completed attempt`() = runBlocking {
        val api = CapturingActivationApi()
        val repository = VoiceCloneEnrollmentRepository(api)

        val response = repository.activateCompletedClone(
            attemptId = "attempt-1",
            improvementConsent = true
        )

        assertEquals("READY", response.status)
        assertEquals("attempt-1", api.attemptId)
        assertEquals(VoiceCloneCompletionActivationRequest(true), api.request)
    }

    @Test
    fun `completion http failure parses the safe backend stage`() = runBlocking {
        val httpFailure = HttpException(
            Response.error<ApiResponse<VoiceCloneStatusResponse>>(
                400,
                """
                    {
                      "code":400,
                      "message":"朗读内容与提示不一致，请重新认证。",
                      "data":{"stage":"ASR_CONTENT"}
                    }
                """.trimIndent()
                    .toResponseBody("application/json".toMediaType())
            )
        )
        val repository = VoiceCloneEnrollmentRepository(FailingCompletionApi(httpFailure))

        val failure = runCatching { repository.complete("attempt-1") }.exceptionOrNull()

        assertTrue(failure is IllegalStateException)
        assertEquals("声音克隆完成失败", failure?.message)
        assertEquals(httpFailure, failure?.cause)
        assertEquals(400, (failure as VoiceCloneCompletionException).httpStatus)
        assertEquals(VoiceCloneCompletionStage.ASR_CONTENT, failure.stage)
    }

    @Test
    fun `completion ignores unknown backend stages`() = runBlocking {
        val httpFailure = HttpException(
            Response.error<ApiResponse<VoiceCloneStatusResponse>>(
                400,
                """{"code":400,"message":"unsafe detail","data":{"stage":"NEW_STAGE"}}"""
                    .toResponseBody("application/json".toMediaType())
            )
        )
        val repository = VoiceCloneEnrollmentRepository(FailingCompletionApi(httpFailure))

        val failure = runCatching { repository.complete("attempt-1") }
            .exceptionOrNull() as VoiceCloneCompletionException

        assertEquals(null, failure.stage)
        assertEquals("声音克隆完成失败", failure.message)
    }

    @Test
    fun `client observation is posted to the owned attempt`() = runBlocking {
        val api = CapturingActivationApi()
        val repository = VoiceCloneEnrollmentRepository(api)
        val request = VoiceCloneVerificationClientObservationRequest(
            deviceModel = "Pixel 10",
            networkType = "WIFI",
            networkValidated = true,
            sdkCode = 2002,
            sdkSubCode = "Z1012",
            reasonCategory = "NETWORK_ACCESS",
            sdkElapsedMs = 8_000L
        )

        repository.reportClientObservation("attempt-observation", request)

        assertEquals("attempt-observation", api.observationAttemptId)
        assertEquals(request, api.observationRequest)
    }

    private class FailingCompletionApi(
        private val failure: HttpException
    ) : VoiceCloneVerificationApi {
        override suspend fun initialize(
            request: VoiceCloneVerificationInitRequest
        ): ApiResponse<VoiceCloneVerificationInitResponse> = error("unused")

        override suspend fun status(
            attemptId: String
        ): ApiResponse<VoiceCloneVerificationStatusResponse> = error("unused")

        override suspend fun reportClientObservation(
            attemptId: String,
            request: VoiceCloneVerificationClientObservationRequest
        ): ApiResponse<VoiceCloneVerificationClientObservationResponse> = error("unused")

        override suspend fun checkReplacement(
            request: VoiceCloneIdentityReplacementCheckRequest
        ): ApiResponse<VoiceCloneIdentityReplacementCheckResponse> = error("unused")

        override suspend fun complete(
            attemptId: String
        ): ApiResponse<VoiceCloneStatusResponse> = throw failure

        override suspend fun activate(
            attemptId: String,
            request: VoiceCloneCompletionActivationRequest
        ): ApiResponse<VoiceCloneStatusResponse> = error("unused")

        override suspend fun createCollection(
            request: VoiceCloneCollectionRequest
        ): ApiResponse<VoiceCloneCollectionResponse> = error("unused")
    }

    private class CapturingActivationApi : VoiceCloneVerificationApi {
        var attemptId: String? = null
        var request: VoiceCloneCompletionActivationRequest? = null
        var observationAttemptId: String? = null
        var observationRequest: VoiceCloneVerificationClientObservationRequest? = null

        override suspend fun initialize(
            request: VoiceCloneVerificationInitRequest
        ): ApiResponse<VoiceCloneVerificationInitResponse> = error("unused")

        override suspend fun status(
            attemptId: String
        ): ApiResponse<VoiceCloneVerificationStatusResponse> = error("unused")

        override suspend fun reportClientObservation(
            attemptId: String,
            request: VoiceCloneVerificationClientObservationRequest
        ): ApiResponse<VoiceCloneVerificationClientObservationResponse> {
            observationAttemptId = attemptId
            observationRequest = request
            return ApiResponse(
                code = 0,
                message = "success",
                timestamp = "2026-08-06T12:00:00",
                data = VoiceCloneVerificationClientObservationResponse(true)
            )
        }

        override suspend fun checkReplacement(
            request: VoiceCloneIdentityReplacementCheckRequest
        ): ApiResponse<VoiceCloneIdentityReplacementCheckResponse> = error("unused")

        override suspend fun complete(
            attemptId: String
        ): ApiResponse<VoiceCloneStatusResponse> = error("unused")

        override suspend fun activate(
            attemptId: String,
            request: VoiceCloneCompletionActivationRequest
        ): ApiResponse<VoiceCloneStatusResponse> {
            this.attemptId = attemptId
            this.request = request
            return ApiResponse(
                code = 0,
                message = "success",
                timestamp = "2026-07-23T21:00:00",
                data = readyStatus()
            )
        }

        override suspend fun createCollection(
            request: VoiceCloneCollectionRequest
        ): ApiResponse<VoiceCloneCollectionResponse> = error("unused")
    }

    private companion object {
        fun readyStatus() = VoiceCloneStatusResponse(
            accountId = "account-a",
            status = "READY",
            active = true,
            speakerId = "voice-a",
            displayName = "我的声音",
            sampleCount = 1,
            lastError = "",
            updatedAt = "2026-07-23T21:00:00",
            enrollmentAvailable = true
        )
    }
}
