package com.vvtech.aiassistant.features.translation_call.backend

import java.net.HttpURLConnection
import java.net.URL
import java.io.IOException
import org.json.JSONArray
import org.json.JSONObject

internal class HttpBackendTranslationClient(
    baseUrl: String
) : BackendTranslationClient {
    private val normalizedBaseUrl = baseUrl.trim().trimEnd('/')

    init {
        require(normalizedBaseUrl.startsWith("http://") || normalizedBaseUrl.startsWith("https://")) {
            "实时翻译服务地址无效"
        }
    }

    override fun loadLanguageCatalog(): BackendTranslationLanguageCatalog {
        val json = requestJson(method = "GET", path = "/api/app-translation-calls/languages")
        val items = json.optJSONArray("languages") ?: JSONArray()
        return BackendTranslationLanguageCatalog(
            buildList {
                for (index in 0 until items.length()) {
                    val item = items.optJSONObject(index) ?: continue
                    val code = item.optString("code").trim()
                    if (code.isNotBlank()) {
                        add(
                            BackendTranslationLanguage(
                                code = code,
                                label = item.optString("label").ifBlank { code }
                            )
                        )
                    }
                }
            }
        )
    }

    override fun createSession(
        request: BackendCreateCallRequest
    ): BackendTranslationCallSession = try {
        createSessionOnce(request)
    } catch (error: IOException) {
        if (request.mediaTransports == BackendMediaTransport.DefaultOrder) {
            createSessionOnce(request.copy(mediaTransports = emptyList()))
        } else {
            throw error
        }
    }

    private fun createSessionOnce(
        request: BackendCreateCallRequest
    ): BackendTranslationCallSession {
        val body = JSONObject()
            .put("merchantPhone", request.merchantPhone)
            .put("userLanguage", request.userLanguage)
            .put("merchantLanguage", request.merchantLanguage)
            .put("scene", "phone_translation")
            .put("voiceProvider", request.voiceProvider)
            .put("realtimeProvider", request.realtimeProvider)
            .put("originalAudioEnabled", request.originalAudioEnabled)
            .put("originalAudioPercent", request.originalAudioPercent)
            .put("originalAudioVolumePercent", request.originalAudioVolumePercent)
        if (request.mediaTransports.isNotEmpty()) {
            body.put(
                "capabilities",
                JSONObject().put("mediaTransports", JSONArray(request.mediaTransports))
            )
        }
        val json = requestJson(
            method = "POST",
            path = "/api/app-translation-calls",
            userId = request.userId,
            body = body
        )
        val callSessionId = json.optString("callSessionId").trim()
        require(callSessionId.isNotBlank()) { "服务端未返回 callSessionId" }
        val appAudioWsUrl = json.optString("appAudioWsUrl").trim()
        val liveKit = parseLiveKit(json.optJSONObject("livekit"))
        val transport = json.optString("mediaTransport").trim().ifBlank {
            if (liveKit != null) BackendMediaTransport.LiveKit else BackendMediaTransport.WebSocket
        }
        if (liveKit == null && appAudioWsUrl.isBlank()) {
            error("服务端未返回可用的实时媒体通道")
        }
        return BackendTranslationCallSession(
            callSessionId = callSessionId,
            status = json.optString("status"),
            appAudioWsUrl = appAudioWsUrl,
            mediaTransport = transport,
            liveKit = liveKit,
            voiceProvider = json.optString("voiceProvider").ifBlank { request.voiceProvider },
            realtimeProvider = json.optString("realtimeProvider")
                .ifBlank { request.realtimeProvider },
            environment = BackendTranslationEnvironmentProtocol.parse(
                json.optJSONObject("environment")
            ),
            originalAudioEnabled = json.optBoolean(
                "originalAudioEnabled",
                request.originalAudioEnabled
            ),
            originalAudioPercent = json.optInt(
                "originalAudioPercent",
                request.originalAudioPercent
            ),
            originalAudioVolumePercent = json.optInt(
                "originalAudioVolumePercent",
                request.originalAudioVolumePercent
            )
        )
    }

    override fun startMerchantCall(
        request: BackendStartMerchantCallRequest
    ): BackendStartMerchantCallResult {
        val json = requestJson(
            method = "POST",
            path = "/api/app-translation-calls/${request.callSessionId}/merchant-call",
            userId = request.userId,
            body = JSONObject()
                .put("merchantPhone", request.merchantPhone)
                .put("voiceProvider", request.voiceProvider)
        )
        return BackendStartMerchantCallResult(
            started = json.optBoolean("started", false),
            environment = BackendTranslationEnvironmentProtocol.parse(
                json.optJSONObject("environment")
            )
        )
    }

    override fun hangup(request: BackendHangupRequest) {
        requestJson(
            method = "POST",
            path = "/api/app-translation-calls/${request.callSessionId}/hangup",
            userId = request.userId,
            allowEmpty = true
        )
    }

    private fun requestJson(
        method: String,
        path: String,
        userId: String? = null,
        body: JSONObject? = null,
        allowEmpty: Boolean = false
    ): JSONObject {
        val connection = URL("$normalizedBaseUrl$path").openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.connectTimeout = NetworkTimeoutMs
        connection.readTimeout = NetworkTimeoutMs
        connection.setRequestProperty("Accept", "application/json")
        if (!userId.isNullOrBlank()) connection.setRequestProperty("x-user-id", userId)
        if (body != null) {
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
        }
        val statusCode = connection.responseCode
        val responseText = try {
            val stream = if (statusCode >= 400) {
                connection.errorStream ?: connection.inputStream
            } else {
                connection.inputStream
            }
            stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        } finally {
            connection.disconnect()
        }
        val json = if (responseText.isBlank() && allowEmpty) {
            JSONObject()
        } else {
            JSONObject(responseText)
        }
        if (statusCode >= 400) {
            throw BackendTranslationHttpException(
                statusCode = statusCode,
                code = json.optString("code").ifBlank { json.optString("error") },
                environment = BackendTranslationEnvironmentProtocol.parse(
                    json.optJSONObject("environment")
                ),
                message = json.optString("message")
                    .ifBlank { json.optString("error") }
                    .ifBlank { "实时翻译服务 HTTP $statusCode" }
            )
        }
        return json
    }

    private fun parseLiveKit(json: JSONObject?): BackendLiveKitConnection? {
        val url = json?.optString("url")?.trim().orEmpty()
        val token = json?.optString("token")?.trim().orEmpty()
        if (url.isBlank() || token.isBlank()) return null
        return BackendLiveKitConnection(
            url = url,
            token = token,
            roomName = json?.optString("roomName")?.trim().orEmpty(),
            participantIdentity = json?.optString("participantIdentity")?.trim().orEmpty()
        )
    }

    private companion object {
        const val NetworkTimeoutMs = 30_000
    }
}
