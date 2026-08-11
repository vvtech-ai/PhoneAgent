package com.vvtech.aiassistant.network

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import okhttp3.Call
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

internal class AppAuthInterceptor(
    private val accessTokenProvider: () -> String,
    private val refreshTokenProvider: () -> String,
    private val tokenUpdater: (String, String) -> Unit,
    private val refreshCallFactory: Call.Factory
) : Interceptor {

    private val refreshLock = Any()

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        if (isPublicAuthPath(request.url.encodedPath)) {
            return chain.proceed(request)
        }
        val originalAccessToken = accessTokenProvider().trim()
        val authenticated = request.withBearer(originalAccessToken)
        val response = chain.proceed(authenticated)
        if (response.code != 401 || refreshTokenProvider().isBlank()) return response

        return synchronized(refreshLock) {
            val currentAccessToken = accessTokenProvider().trim()
            if (currentAccessToken.isNotBlank() && currentAccessToken != originalAccessToken) {
                response.close()
                return@synchronized chain.proceed(request.withBearer(currentAccessToken))
            }
            val renewed = refresh(request) ?: return@synchronized response
            tokenUpdater(renewed.first, renewed.second)
            response.close()
            chain.proceed(request.withBearer(renewed.first))
        }
    }

    private fun refresh(originalRequest: Request): Pair<String, String>? {
        val refreshToken = refreshTokenProvider().trim()
        if (refreshToken.isBlank()) return null
        val body = JsonObject().apply { addProperty("refreshToken", refreshToken) }
            .toString()
            .toRequestBody(JsonMediaType)
        val refreshRequest = Request.Builder()
            .url(
                originalRequest.url.newBuilder()
                    .encodedPath(refreshPath(originalRequest.url.encodedPath))
                    .query(null)
                    .build()
            )
            .post(body)
            .build()
        return runCatching {
            refreshCallFactory.newCall(refreshRequest).execute().use { response ->
                if (!response.isSuccessful) return@use null
                val root = JsonParser.parseString(response.body?.string().orEmpty()).asJsonObject
                if (root.get("code")?.asInt != 0) return@use null
                val data = root.getAsJsonObject("data") ?: return@use null
                val access = data.get("accessToken")?.asString.orEmpty().trim()
                val refresh = data.get("refreshToken")?.asString.orEmpty().trim()
                if (access.isBlank() || refresh.isBlank()) null else access to refresh
            }
        }.getOrNull()
    }

    private fun Request.withBearer(token: String): Request = if (token.isBlank()) {
        this
    } else {
        newBuilder().header("Authorization", "Bearer $token").build()
    }

    private fun isPublicAuthPath(path: String): Boolean =
        path.endsWith("/api/auth/sms/send-code") ||
            path.endsWith("/api/auth/sms/login") ||
            path.endsWith("/api/auth/session/refresh")

    private fun refreshPath(originalPath: String): String {
        val apiSegment = originalPath.indexOf("/api/")
        val gatewayPrefix = if (apiSegment >= 0) originalPath.substring(0, apiSegment) else ""
        return "$gatewayPrefix/api/auth/session/refresh"
    }

    private companion object {
        val JsonMediaType = "application/json; charset=utf-8".toMediaType()
    }
}
