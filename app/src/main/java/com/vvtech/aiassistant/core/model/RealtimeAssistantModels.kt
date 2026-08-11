package com.vvtech.aiassistant.core.model

import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.UserContextPayload

data class RealtimeToolDefinition(
    val name: String,
    val description: String,
    val parametersJsonSchema: Map<String, Any?> = emptyMap()
)

data class RealtimeRtcJoinConfig(
    val appId: String,
    val roomId: String,
    val userId: String,
    val token: String,
    val tokenExpireEpochSeconds: Long
)

data class RealtimeSessionResponse(
    val sessionId: String,
    val taskId: String,
    val sceneType: String,
    val taskStatus: String,
    val ready: Boolean,
    val agentReady: Boolean,
    val backendCallEnabled: Boolean,
    val statusMessage: String,
    val rtc: RealtimeRtcJoinConfig? = null,
    val currentSlots: Map<String, String> = emptyMap(),
    val systemMessages: List<String> = emptyList(),
    val tools: List<RealtimeToolDefinition> = emptyList()
)

data class StopRealtimeSessionResponse(
    val sessionId: String,
    val status: String,
    val message: String
)

data class UpdateRealtimeContextRequest(
    val userId: String,
    val sessionId: String,
    val taskId: String? = null,
    val speakLatestAssistantMessage: Boolean? = null
)

data class UpdateRealtimeContextResponse(
    val sessionId: String,
    val status: String,
    val message: String
)

data class VoiceClientDiagnosticRequest(
    val source: String,
    val severity: String,
    val userId: String? = null,
    val taskId: String? = null,
    val sceneType: String? = null,
    val dialogKey: String? = null,
    val languageCode: String? = null,
    val generation: Long? = null,
    val sdkEventType: Int? = null,
    val sessionAgeMs: Long? = null,
    val message: String? = null,
    val payload: String? = null,
    val throwableType: String? = null,
    val stackTrace: String? = null,
    val timestampMs: Long = System.currentTimeMillis()
)

data class CallSessionStatusResponse(
    val callId: String,
    val taskId: String,
    val sceneType: String,
    val targetName: String,
    val phoneNumber: String,
    val callState: String,
    val handoffMode: String,
    val backendCallEnabled: Boolean,
    val handoffSupported: Boolean,
    val appRtcRequired: Boolean,
    val takeoverRtc: RealtimeRtcJoinConfig? = null,
    val dialogueDetail: String = "",
    val statusMessage: String,
    val resultCode: String = "",
    val resultReason: String = "",
    val resultText: String = "",
    val updatedAt: String
)

data class StartRealtimeSessionRequest(
    val userId: String,
    val taskId: String? = null,
    val startFresh: Boolean? = null,
    val userContext: UserContextPayload? = null,
    val languageCode: String? = null
)

data class StopRealtimeSessionRequest(
    val userId: String,
    val sessionId: String,
    val taskId: String? = null
)

data class CallSessionStatusRequest(
    val userId: String,
    val taskId: String? = null,
    val callId: String? = null
)

data class CallHandoffRequest(
    val userId: String,
    val taskId: String? = null,
    val callId: String? = null,
    val reason: String? = null
)

data class CallMonitorTokenRequest(
    val userId: String,
    val taskId: String? = null,
    val callId: String
)

data class CallMonitorTokenResponse(
    val ticket: String,
    val expiresAt: String,
    val sampleRate: Int = 16_000,
    val channels: Int = 1,
    val encoding: String = "PCM_S16LE"
)

typealias RealtimeSessionApiResponse = ApiResponse<RealtimeSessionResponse>
typealias StopRealtimeSessionApiResponse = ApiResponse<StopRealtimeSessionResponse>
typealias UpdateRealtimeContextApiResponse = ApiResponse<UpdateRealtimeContextResponse>
typealias CallSessionStatusApiResponse = ApiResponse<CallSessionStatusResponse>
typealias CallMonitorTokenApiResponse = ApiResponse<CallMonitorTokenResponse>
typealias VoiceClientDiagnosticApiResponse = ApiResponse<Map<String, String>>

enum class TranslationLanguageMode {
    AUTO,
    MANUAL
}

enum class TranslationVoiceMode {
    DEFAULT,
    USER_CLONE
}

data class TranslationVoiceCapabilitiesResponse(
    val provider: String,
    val translationSupported: Boolean,
    val voiceCapability: String,
    val builtInVoices: List<String> = emptyList()
)

data class StartTranslationCallRequest(
    val userId: String,
    val phoneNumber: String,
    val displayName: String? = null,
    val languageMode: TranslationLanguageMode = TranslationLanguageMode.AUTO,
    val callerPreferredLanguage: String? = null,
    val calleePreferredLanguage: String? = null,
    val voiceMode: TranslationVoiceMode = TranslationVoiceMode.DEFAULT,
    val preferredVoice: String? = null
)

data class TranslationCallStartResponse(
    val callId: String,
    val callState: String,
    val translationState: String,
    val provider: String,
    val voiceCapability: String,
    val callerDetectedLanguage: String,
    val calleeDetectedLanguage: String,
    val effectiveCallerToCalleeVoice: String,
    val passthroughActive: Boolean = false,
    val passthroughReason: String? = null,
    val statusMessage: String
)

data class TranslationCallSubtitleItem(
    val speakerRole: String,
    val sourceLanguage: String,
    val sourceText: String,
    val translatedLanguage: String,
    val translatedText: String
)

data class TranslationCallStatusRequest(
    val userId: String,
    val callId: String
)

data class TranslationCallHangupRequest(
    val userId: String,
    val callId: String
)

data class TranslationLanguageOverrideRequest(
    val userId: String,
    val callId: String,
    val callerPreferredLanguage: String? = null,
    val calleePreferredLanguage: String? = null,
    val preferredVoice: String? = null
)

data class TranslationCallStatusResponse(
    val callId: String,
    val callState: String,
    val translationState: String,
    val provider: String,
    val callerDetectedLanguage: String,
    val calleeDetectedLanguage: String,
    val effectiveCallerToCalleeVoice: String,
    val voiceCapability: String,
    val subtitleItems: List<TranslationCallSubtitleItem> = emptyList(),
    val passthroughActive: Boolean = false,
    val passthroughReason: String? = null,
    val statusMessage: String,
    val updatedAt: String
)

typealias TranslationVoiceCapabilitiesApiResponse = ApiResponse<TranslationVoiceCapabilitiesResponse>
typealias TranslationCallStartApiResponse = ApiResponse<TranslationCallStartResponse>
typealias TranslationCallStatusApiResponse = ApiResponse<TranslationCallStatusResponse>

data class VoiceDialogContextRequest(
    val userId: String,
    val taskId: String? = null,
    val currentScene: String? = null,
    val latestUserUtterance: String? = null,
    val userContext: UserContextPayload? = null,
    val languageCode: String? = null
)

data class VoiceDialogContextResponse(
    val taskId: String? = null,
    val sceneType: String,
    val dialogKey: String = "",
    val botName: String = "AI 助手",
    val statusMessage: String,
    val systemMessages: List<String> = emptyList(),
    val currentSlots: Map<String, String> = emptyMap(),
    val sessionPayload: Map<String, Any?> = emptyMap()
)

typealias VoiceDialogContextApiResponse = ApiResponse<VoiceDialogContextResponse>

data class DetailSupplementQuestionResponse(
    val questionId: String,
    val prompt: String,
    val answerType: String = "boolean",
    val dependsOnQuestionId: String? = null,
    val dependsOnAnswer: String? = null
)

data class DetailSupplementPromptResponse(
    val sceneType: String,
    val title: String,
    val intro: String,
    val questions: List<DetailSupplementQuestionResponse> = emptyList()
)

typealias DetailSupplementPromptApiResponse = ApiResponse<DetailSupplementPromptResponse>
