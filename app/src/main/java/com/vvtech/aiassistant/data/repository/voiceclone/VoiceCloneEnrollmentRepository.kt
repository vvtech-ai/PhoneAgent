package com.vvtech.aiassistant.data.repository.voiceclone

import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationApi
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCollectionRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCollectionResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneCompletionActivationRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationInitRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationInitResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationClientObservationRequest
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationStatusResponse
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneIdentityReplacementCheckRequest
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import retrofit2.HttpException

internal class VoiceCloneEnrollmentRepository(
    private val api: VoiceCloneVerificationApi
) {
    suspend fun initialize(
        consentVersion: String,
        realName: String,
        certNo: String,
        metaInfo: String,
        replacementConfirmed: Boolean
    ): VoiceCloneVerificationInitResponse = api.initialize(
        VoiceCloneVerificationInitRequest(
            consentVersion = consentVersion,
            realName = realName.trim(),
            certNo = certNo.trim().uppercase(),
            metaInfo = metaInfo,
            replacementConfirmed = replacementConfirmed
        )
    ).requireData()

    suspend fun checkReplacement(certNo: String): Boolean = api.checkReplacement(
        VoiceCloneIdentityReplacementCheckRequest(certNo = certNo.trim().uppercase())
    ).requireData().replacementRequired

    suspend fun status(attemptId: String): VoiceCloneVerificationStatusResponse =
        api.status(attemptId).requireData()

    suspend fun reportClientObservation(
        attemptId: String,
        request: VoiceCloneVerificationClientObservationRequest
    ) {
        val response = api.reportClientObservation(attemptId, request)
        if (response.code != 0 || response.data?.accepted != true) {
            throw IllegalStateException(response.message.ifBlank { "认证观测上报失败" })
        }
    }

    suspend fun complete(attemptId: String): VoiceCloneStatusResponse {
        val response = try {
            api.complete(attemptId)
        } catch (error: HttpException) {
            throw error.toVoiceCloneCompletionException()
        }
        return response.requireData()
    }

    suspend fun activateCompletedClone(
        attemptId: String,
        improvementConsent: Boolean
    ): VoiceCloneStatusResponse = api.activate(
        attemptId,
        VoiceCloneCompletionActivationRequest(improvementConsent)
    ).requireData()

    suspend fun createCollection(
        attemptId: String,
        previousScriptId: String?
    ): VoiceCloneCollectionResponse = api.createCollection(
        VoiceCloneCollectionRequest(attemptId, previousScriptId)
    ).requireData()

    private fun <T> com.vvtech.aiassistant.model.ApiResponse<T>.requireData(): T {
        if (code != 0) throw IllegalStateException(message)
        return data ?: throw IllegalStateException("服务端返回了空数据")
    }
}
