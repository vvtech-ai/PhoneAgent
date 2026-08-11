package com.vvtech.aiassistant.network

import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.remote.ocr.ConversationOcrAttachmentApi
import com.vvtech.aiassistant.data.remote.evaluation.AgentCallEvaluationApi
import com.vvtech.aiassistant.data.remote.recording.CallRecordingApi
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineApi
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationApi
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object NetworkModule {

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BASIC
    }

    private val authRefreshClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(90, TimeUnit.SECONDS)
        .addInterceptor(loggingInterceptor)
        .build()

    private fun appAuthInterceptor() = AppAuthInterceptor(
        accessTokenProvider = { AccountIdentityProvider.accessToken },
        refreshTokenProvider = { AccountIdentityProvider.refreshToken },
        tokenUpdater = AccountIdentityProvider::updateSessionTokens,
        refreshCallFactory = authRefreshClient
    )

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(90, TimeUnit.SECONDS)
        .addInterceptor(
            appAuthInterceptor()
        )
        .addInterceptor(loggingInterceptor)
        .build()

    /**
     * Dedicated client for SSE / long-lived streaming responses.
     *
     * OkHttp's readTimeout fires if no bytes are received within the window.
     * For SSE connections that may be silent for minutes (e.g. during a SIP call),
     * we set readTimeout to 0 (infinite) and rely on server-side heartbeats +
     * the coroutine's structured cancellation to terminate the stream instead.
     */
    private val streamingOkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)   // no per-read timeout for SSE
        .writeTimeout(90, TimeUnit.SECONDS)
        .addInterceptor(appAuthInterceptor())
        .addInterceptor(loggingInterceptor)
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    private val streamingRetrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.BASE_URL)
        .client(streamingOkHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    val taskApiService: TaskApiService = retrofit.create(TaskApiService::class.java)
    val assistantApiService: AssistantApiService = retrofit.create(AssistantApiService::class.java)
    val conversationTimelineApi: ConversationTimelineApi = retrofit.create(ConversationTimelineApi::class.java)
    val conversationOcrAttachmentApi: ConversationOcrAttachmentApi =
        retrofit.create(ConversationOcrAttachmentApi::class.java)
    internal val callRecordingApi: CallRecordingApi =
        retrofit.create(CallRecordingApi::class.java)
    internal val agentCallEvaluationApi: AgentCallEvaluationApi =
        retrofit.create(AgentCallEvaluationApi::class.java)
    internal val voiceCloneVerificationApi: VoiceCloneVerificationApi =
        retrofit.create(VoiceCloneVerificationApi::class.java)

    /** Use this service for SSE/streaming endpoints only (readTimeout = infinite). */
    val streamingAssistantApiService: AssistantApiService =
        streamingRetrofit.create(AssistantApiService::class.java)
}
