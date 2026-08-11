package com.vvtech.aiassistant.repository

import com.google.gson.JsonParser
import com.vvtech.aiassistant.account.AccountIdentityProvider
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
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeCallModelLatencyResponse
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
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.model.VoiceCloneScriptsResponse
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.model.VoiceCloneUploadRequest
import com.vvtech.aiassistant.network.NetworkModule
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException
import java.io.File

object AppContainer {
    val taskRepository: TaskRepository by lazy { TaskRepository() }
}

class TaskRepository {

    private val api = NetworkModule.taskApiService

    suspend fun createTask(
        userId: String,
        originText: String,
        userContext: UserContextPayload? = null
    ): TaskConversationResponse {
        return unwrap(api.createTask(CreateTaskRequest(userId = userId, originText = originText, userContext = userContext)))
    }

    suspend fun chat(
        taskId: String,
        message: String,
        userContext: UserContextPayload? = null
    ): TaskConversationResponse {
        return unwrap(api.chat(TaskChatRequest(taskId = taskId, message = message, userContext = userContext)))
    }

    suspend fun confirm(taskId: String, confirmed: Boolean): TaskConfirmResponse {
        return unwrap(api.confirm(TaskConfirmRequest(taskId = taskId, confirmed = confirmed)))
    }

    suspend fun getRestaurants(taskId: String): RestaurantListResponse {
        return unwrap(api.getRestaurants(taskId))
    }

    suspend fun selectRestaurant(taskId: String, restaurantId: String): TaskActionResponse {
        return unwrap(api.selectRestaurant(SelectRestaurantRequest(taskId = taskId, restaurantId = restaurantId)))
    }

    suspend fun callTask(taskId: String): CallTaskResponse {
        return unwrap(api.callTask(CallTaskRequest(taskId = taskId)))
    }

    suspend fun getTaskDetail(taskId: String): TaskDetailResponse {
        return unwrap(api.getTaskDetail(taskId))
    }

    suspend fun listTasks(userId: String? = null): List<TaskListItem> {
        return unwrap(api.listTasks(userId))
    }

    suspend fun listCallHistory(userId: String? = null): List<AssistantCallHistoryItem> {
        return unwrap(api.listCallHistory(userId))
    }

    suspend fun acquireClientSipLease(
        route: String,
        purpose: String,
        callId: String? = null,
        deviceId: String? = null
    ): ClientSipLeaseResponse {
        return unwrap(
            api.acquireClientSipLease(
                ClientSipLeaseRequest(
                    route = route,
                    purpose = purpose,
                    callId = callId,
                    deviceId = deviceId
                )
            )
        )
    }

    suspend fun releaseClientSipLease(
        leaseId: String,
        reason: String? = null,
        callId: String? = null,
        deviceId: String? = null
    ): ClientSipLeaseReleaseResponse {
        return unwrap(
            api.releaseClientSipLease(
                leaseId = leaseId,
                request = ClientSipLeaseReleaseRequest(
                    reason = reason,
                    callId = callId,
                    deviceId = deviceId
                )
            )
        )
    }

    suspend fun sendSmsLoginCode(phone: String): SmsLoginSendCodeResponse {
        return try {
            unwrap(api.sendSmsLoginCode(SmsLoginSendCodeRequest(phone = phone)))
        } catch (ex: HttpException) {
            throw IllegalStateException(readTaskApiErrorMessage(ex), ex)
        }
    }

    suspend fun loginWithSmsCode(
        phone: String,
        code: String,
        activationCode: String? = null,
        loginChallenge: String? = null
    ): SmsLoginResponse {
        return try {
            unwrap(
                api.loginWithSmsCode(
                    SmsLoginRequest(
                        phone = phone,
                        code = code,
                        activationCode = activationCode?.trim()?.takeIf { it.isNotBlank() },
                        loginChallenge = loginChallenge?.trim()?.takeIf { it.isNotBlank() }
                    )
                )
            )
        } catch (ex: HttpException) {
            throw IllegalStateException(readTaskApiErrorMessage(ex), ex)
        }
    }

    suspend fun logoutAppSession(authorization: String) {
        val response = api.logoutAppSession(authorization)
        if (response.code != 0) {
            throw IllegalStateException(response.message)
        }
    }

    suspend fun getOutboundNumberSettings(): OutboundNumberSettingsResponse {
        return unwrap(api.getOutboundNumberSettings())
    }

    suspend fun updateOutboundNumberSettings(outboundNumber: String): OutboundNumberSettingsResponse {
        return unwrap(api.updateOutboundNumberSettings(UpdateOutboundNumberRequest(outboundNumber = outboundNumber)))
    }

    suspend fun deleteOutboundNumberSettings(): OutboundNumberSettingsResponse {
        return unwrap(api.deleteOutboundNumberSettings())
    }

    suspend fun getRealtimeCallProviderSettings(): RealtimeCallProviderResponse {
        return unwrap(api.getRealtimeCallProviderSettings())
    }

    suspend fun getRealtimeCallModelLatencies(refresh: Boolean = false): RealtimeCallModelLatencyResponse {
        return unwrap(api.getRealtimeCallModelLatencies(refresh = refresh))
    }

    suspend fun updateRealtimeCallProviderSettings(provider: String): RealtimeCallProviderResponse {
        return unwrap(api.updateRealtimeCallProviderSettings(UpdateRealtimeCallProviderRequest(provider = provider)))
    }

    suspend fun getRealtimeCallVoiceSettings(): RealtimeCallVoiceResponse {
        return unwrap(api.getRealtimeCallVoiceSettings())
    }

    suspend fun updateRealtimeCallVoiceSettings(
        voice: String?,
        selectionMode: String = "AI"
    ): RealtimeCallVoiceResponse {
        return mapTaskApiHttpError {
            unwrap(
                api.updateRealtimeCallVoiceSettings(
                    UpdateRealtimeCallVoiceRequest(voice = voice, selectionMode = selectionMode)
                )
            )
        }
    }

    suspend fun getRealtimeTranslationProviderSettings(): RealtimeTranslationProviderResponse {
        return unwrap(api.getRealtimeTranslationProviderSettings())
    }

    suspend fun updateRealtimeTranslationProviderSettings(provider: String): RealtimeTranslationProviderResponse {
        return unwrap(
            api.updateRealtimeTranslationProviderSettings(
                UpdateRealtimeTranslationProviderRequest(provider = provider)
            )
        )
    }

    suspend fun checkAppVersion(
        packageName: String,
        currentVersionCode: Long,
        currentVersionName: String,
        deviceId: String? = null,
        channel: String? = null
    ): OtaVersionCheckResponse {
        return unwrap(
            api.checkAppVersion(
                OtaVersionCheckRequest(
                    packageName = packageName,
                    currentVersionCode = currentVersionCode,
                    currentVersionName = currentVersionName,
                    deviceId = deviceId,
                    channel = channel
                )
            )
        )
    }

    suspend fun uploadAppLogs(zipFile: File, deviceInfo: String): AppLogUploadResponse {
        val fileBody = zipFile.asRequestBody("application/zip".toMediaTypeOrNull())
        val filePart = MultipartBody.Part.createFormData("file", zipFile.name, fileBody)
        return unwrap(
            api.uploadAppLogs(
                file = filePart,
                accountId = AccountIdentityProvider.accountId.toRequestBody("text/plain".toMediaTypeOrNull()),
                deviceInfo = deviceInfo.toRequestBody("text/plain".toMediaTypeOrNull())
            )
        )
    }

    suspend fun getVoiceCloneStatus(): VoiceCloneStatusResponse {
        return unwrap(api.getVoiceCloneStatus())
    }

    suspend fun getVoiceCloneScripts(): VoiceCloneScriptsResponse {
        return unwrap(api.getVoiceCloneScripts())
    }

    suspend fun uploadVoiceCloneSamples(request: VoiceCloneUploadRequest): VoiceCloneStatusResponse {
        return try {
            unwrap(api.uploadVoiceCloneSamples(request))
        } catch (ex: HttpException) {
            throw IllegalStateException(readTaskApiErrorMessage(ex), ex)
        }
    }

    suspend fun activateVoiceClone(): VoiceCloneStatusResponse {
        return unwrap(api.activateVoiceClone())
    }

    suspend fun deactivateVoiceClone(): VoiceCloneStatusResponse {
        return unwrap(api.deactivateVoiceClone())
    }

    private fun <T> unwrap(response: com.vvtech.aiassistant.model.ApiResponse<T>): T {
        if (response.code != 0) {
            throw IllegalStateException(response.message)
        }
        return response.data ?: throw IllegalStateException("服务端返回了空数据")
    }

}

internal suspend fun <T> mapTaskApiHttpError(block: suspend () -> T): T =
    try {
        block()
    } catch (ex: HttpException) {
        throw IllegalStateException(readTaskApiErrorMessage(ex), ex)
    }

private fun readTaskApiErrorMessage(ex: HttpException): String {
    val fallback = ex.message ?: "HTTP ${ex.code()}"
    val rawBody = runCatching { ex.response()?.errorBody()?.string() }.getOrNull()
    if (rawBody.isNullOrBlank()) return fallback
    return runCatching {
        val root = JsonParser().parse(rawBody).asJsonObject
        root.get("message")?.asString?.takeIf { it.isNotBlank() } ?: fallback
    }.getOrDefault(fallback)
}
