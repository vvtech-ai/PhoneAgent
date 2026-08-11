package com.vvtech.aiassistant.data.remote.voiceclone

import com.google.gson.JsonParser
import com.vvtech.aiassistant.logging.AppFileLogger
import okhttp3.Call
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response
import okhttp3.RequestBody.Companion.toRequestBody

internal class VoiceCloneAuthorizationPolicy(
    private val tokenProvider: () -> String
) {
    fun authorizationHeader(path: String): String? {
        if (!isProtectedPath(path)) return null
        val token = tokenProvider().trim()
        return token.takeIf { it.isNotEmpty() }?.let { "Bearer $it" }
    }

    fun isVoiceClonePath(path: String): Boolean {
        val prefixStart = path.indexOf(VoiceClonePathPrefix)
        if (prefixStart < 0) return false
        val suffixStart = prefixStart + VoiceClonePathPrefix.length
        return suffixStart == path.length || path[suffixStart] == '/'
    }

    fun isProtectedPath(path: String): Boolean =
        isVoiceClonePath(path) || exactPath(path, ClientLogUploadPath)

    fun refreshPath(path: String): String? {
        val prefixStart = path.indexOf(VoiceClonePathPrefix)
        if (prefixStart >= 0) return path.substring(0, prefixStart) + VoiceCloneRefreshPath
        val logPathStart = path.indexOf(ClientLogUploadPath)
        return if (logPathStart >= 0 && logPathStart + ClientLogUploadPath.length == path.length) {
            path.substring(0, logPathStart) + VoiceCloneRefreshPath
        } else {
            null
        }
    }

    fun legacyRecoveryPath(path: String): String? {
        val prefixStart = path.indexOf(VoiceClonePathPrefix)
        if (prefixStart < 0) return null
        return path.substring(0, prefixStart) + VoiceCloneLegacyRecoveryPath
    }

    private companion object {
        const val VoiceClonePathPrefix = "/api/account/settings/voice-clone"
        const val VoiceCloneRefreshPath = "/api/auth/voice-clone/refresh"
        const val VoiceCloneLegacyRecoveryPath =
            "/api/auth/voice-clone/legacy-recovery"
        const val ClientLogUploadPath = "/api/logs/upload"
    }

    private fun exactPath(path: String, expected: String): Boolean {
        val start = path.indexOf(expected)
        return start >= 0 && start + expected.length == path.length
    }
}

internal class VoiceCloneAuthInterceptor(
    private val tokenProvider: () -> String,
    private val tokenUpdater: (String) -> Unit = {},
    private val refreshCallFactory: Call.Factory
) : Interceptor {
    private val policy = VoiceCloneAuthorizationPolicy(tokenProvider)
    private val refreshLock = Any()

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        if (!policy.isProtectedPath(request.url.encodedPath)) {
            return chain.proceed(request)
        }
        val originalToken = tokenProvider().trim()
        val authorization = policy.authorizationHeader(request.url.encodedPath)
        val response = chain.proceed(
            authorization?.let { request.withAuthorization(it) } ?: request
        )
        if (response.code != 401) return response

        return synchronized(refreshLock) {
            val currentToken = tokenProvider().trim()
            if (currentToken.isNotBlank() && currentToken != originalToken) {
                response.close()
                return@synchronized chain.proceed(
                    request.withAuthorization("Bearer $currentToken")
                )
            }

            val renewedToken = if (originalToken.isBlank()) {
                recoverLegacyToken(request)
            } else {
                refreshToken(request, originalToken)
            }
                ?: return@synchronized response
            tokenUpdater(renewedToken)
            response.close()
            chain.proceed(request.withAuthorization("Bearer $renewedToken"))
        }
    }

    private fun refreshToken(
        request: Request,
        expiredToken: String
    ): String? =
        requestToken(
            request = request,
            tokenPath = policy.refreshPath(request.url.encodedPath),
            authorization = "Bearer $expiredToken",
            operation = "REFRESH"
        )

    private fun recoverLegacyToken(request: Request): String? =
        requestToken(
            request = request,
            tokenPath = policy.legacyRecoveryPath(request.url.encodedPath),
            authorization = null,
            operation = "LEGACY_RECOVERY"
        )

    private fun requestToken(
        request: Request,
        tokenPath: String?,
        authorization: String?,
        operation: String
    ): String? {
        if (operation == "REFRESH" && authorization.isNullOrBlank()) return null
        val resolvedPath = tokenPath ?: return null
        val refreshUrl = request.url.newBuilder()
            .encodedPath(resolvedPath)
            .query(null)
            .build()
        val refreshRequestBuilder = Request.Builder()
            .url(refreshUrl)
            .post(ByteArray(0).toRequestBody(null))
        if (!authorization.isNullOrBlank()) {
            refreshRequestBuilder.header("Authorization", authorization)
        }
        val refreshRequest = refreshRequestBuilder.build()
        return runCatching {
            refreshCallFactory.newCall(refreshRequest).execute().use { refreshResponse ->
                if (!refreshResponse.isSuccessful) return@use null
                val root = JsonParser().parse(
                    refreshResponse.body?.string().orEmpty()
                ).asJsonObject
                if (root.get("code")?.asInt != 0) return@use null
                root.getAsJsonObject("data")
                    ?.get("voiceCloneAccessToken")
                    ?.asString
                    ?.trim()
                    ?.takeIf(String::isNotEmpty)
            }
        }.onSuccess { renewedToken ->
            AppFileLogger.i(
                LogTag,
                if (renewedToken == null) {
                    "VOICE_CLONE_TOKEN_${operation}_FAILED result=invalid_response"
                } else {
                    "VOICE_CLONE_TOKEN_${operation}_COMPLETED result=success"
                }
            )
        }.onFailure { error ->
            AppFileLogger.w(
                LogTag,
                "VOICE_CLONE_TOKEN_${operation}_FAILED result=request_error " +
                    "exception=${error.javaClass.simpleName}"
            )
        }.getOrNull()
    }

    private fun Request.withAuthorization(authorization: String): Request =
        newBuilder()
            .header("Authorization", authorization)
            .build()

    private companion object {
        const val LogTag = "VoiceCloneAuth"
    }
}
