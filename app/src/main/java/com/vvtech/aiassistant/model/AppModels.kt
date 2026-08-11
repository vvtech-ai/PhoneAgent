package com.vvtech.aiassistant.model

data class ApiResponse<T>(
    val code: Int,
    val message: String,
    val timestamp: String,
    val data: T?
)

data class OcrContextFieldPayload(
    val label: String,
    val value: String
)

data class OcrAttachmentContextPayload(
    val attachmentId: String,
    val fields: List<OcrContextFieldPayload>,
    val segments: List<String>,
    val fullText: String
)

data class UserContextPayload(
    val city: String? = null,
    val district: String? = null,
    val adcode: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val defaultReservationContact: DefaultReservationContactPayload? = null,
    val reservationContacts: List<DefaultReservationContactPayload>? = null,
    val currentTime: UserCurrentTimePayload? = null,
    val permissionStatus: Map<String, String>? = null,
    val deviceContacts: List<DeviceContactPayload>? = null,
    val ocrAttachments: List<OcrAttachmentContextPayload>? = null
)

data class DeviceContactPayload(
    val contactName: String,
    val phoneNumber: String? = null,
    val status: String = "FOUND"
)

data class DefaultReservationContactPayload(
    val name: String? = null,
    val gender: String? = null,
    val phone: String? = null,
    val idCardNumber: String? = null,
    val isDefault: Boolean? = null
)

data class UserCurrentTimePayload(
    val isoDateTime: String? = null,
    val timezone: String? = null
)

data class ReservationSlot(
    val reservationTime: String? = null,
    val partySize: Int? = null,
    val restaurantName: String? = null,
    val locationIntent: String? = null,
    val cuisine: String? = null,
    val contactPhone: String? = null,
    val allowAlternativeTime: Boolean? = null
)

data class Restaurant(
    val restaurantId: String,
    val name: String,
    val phone: String,
    val address: String,
    val distanceMeters: Int? = null,
    val district: String? = null
)

data class CallRecord(
    val callId: String,
    val taskId: String,
    val status: String,
    val result: String,
    val summary: String
)

data class TaskConversationResponse(
    val taskId: String,
    val status: String,
    val aiMessage: String,
    val slot: ReservationSlot,
    val complete: Boolean,
    val missingFields: List<String>
)

data class TaskConfirmResponse(
    val taskId: String,
    val status: String,
    val summary: String,
    val slot: ReservationSlot,
    val readyForRestaurant: Boolean
)

data class RestaurantListResponse(
    val taskId: String,
    val status: String,
    val selectedRestaurantId: String?,
    val restaurants: List<Restaurant>
)

data class TaskActionResponse(
    val taskId: String,
    val status: String,
    val message: String
)

data class CallTaskResponse(
    val taskId: String,
    val callId: String,
    val status: String,
    val result: String,
    val summary: String
)

data class TaskDetailResponse(
    val taskId: String,
    val userId: String,
    val status: String,
    val originText: String,
    val finalResult: String?,
    val selectedRestaurantId: String?,
    val createdAt: String,
    val slot: ReservationSlot,
    val selectedRestaurant: Restaurant?,
    val restaurants: List<Restaurant>,
    val callRecords: List<CallRecord>
)

data class TaskListItem(
    val taskId: String,
    val userId: String,
    val status: String,
    val originText: String,
    val finalResult: String?,
    val callResultCode: String? = null,
    val callResultText: String? = null,
    val slot: ReservationSlot? = null,
    val createdAt: String
)

data class CreateTaskRequest(
    val userId: String,
    val originText: String,
    val userContext: UserContextPayload? = null
)

data class TaskChatRequest(
    val taskId: String,
    val message: String,
    val userContext: UserContextPayload? = null
)

data class TaskConfirmRequest(
    val taskId: String,
    val confirmed: Boolean
)

data class SelectRestaurantRequest(
    val taskId: String,
    val restaurantId: String
)

data class CallTaskRequest(
    val taskId: String
)

data class OutboundNumberSettingsResponse(
    val accountId: String,
    val outboundNumber: String,
    val configured: Boolean
)

data class UpdateOutboundNumberRequest(
    val outboundNumber: String
)

data class SmsLoginSendCodeRequest(
    val phone: String
)

data class SmsLoginSendCodeResponse(
    val phone: String,
    val expireSeconds: Int,
    val resendCooldownSeconds: Int,
    val eventId: String
)

data class SmsLoginRequest(
    val phone: String,
    val code: String,
    val activationCode: String? = null,
    val loginChallenge: String? = null
)

data class SmsLoginResponse(
    val accountId: String,
    val phone: String,
    val displayName: String,
    val inviteRequired: Boolean = false,
    val voiceCloneAccessToken: String = "",
    val loginChallenge: String? = null,
    val accessToken: String = "",
    val refreshToken: String = "",
    val accessTokenExpiresIn: Long = 0,
    val refreshTokenExpiresIn: Long = 0
)

data class RealtimeCallProviderItem(
    val provider: String,
    val displayName: String,
    val description: String? = null,
    val active: Boolean,
    val configured: Boolean,
    val available: Boolean,
    val statusMessage: String
)

data class RealtimeCallProviderResponse(
    val activeProvider: String,
    val activeProviderDisplayName: String,
    val source: String,
    val updatedAt: String?,
    val providers: List<RealtimeCallProviderItem>
)

data class UpdateRealtimeCallProviderRequest(
    val provider: String
)

data class AssistantCallHistoryItem(
    val callId: String,
    val callAttemptId: String? = null,
    val taskId: String? = null,
    val targetName: String? = null,
    val phoneNumber: String? = null,
    val callState: String? = null,
    val resultCode: String? = null,
    val resultReason: String? = null,
    val statusMessage: String? = null,
    val dialogueSummary: String? = null,
    val dialogueDetail: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

data class RealtimeCallVoiceItem(
    val voice: String,
    val displayName: String,
    val description: String,
    val selected: Boolean,
    val defaultVoice: Boolean
)

data class RealtimeCallVoiceResponse(
    val activeVoice: String,
    val activeVoiceDisplayName: String,
    val defaultVoice: String,
    val source: String,
    val updatedAt: String?,
    val voices: List<RealtimeCallVoiceItem>,
    val selectionMode: String = "AI"
)

data class UpdateRealtimeCallVoiceRequest(
    val voice: String?,
    val selectionMode: String = "AI"
)

data class RealtimeTranslationProviderItem(
    val provider: String,
    val displayName: String,
    val active: Boolean,
    val configured: Boolean,
    val available: Boolean,
    val statusMessage: String
)

data class RealtimeTranslationProviderResponse(
    val activeProvider: String,
    val activeProviderDisplayName: String,
    val source: String,
    val updatedAt: String?,
    val providers: List<RealtimeTranslationProviderItem>
)

data class UpdateRealtimeTranslationProviderRequest(
    val provider: String
)

data class OtaVersionCheckRequest(
    val packageName: String,
    val currentVersionCode: Long,
    val currentVersionName: String,
    val deviceId: String? = null,
    val channel: String? = null
)

data class OtaVersionCheckResponse(
    val hasUpdate: Boolean,
    val packageName: String,
    val versionName: String,
    val versionCode: Long?,
    val forceUpdate: Boolean,
    val apkUrl: String,
    val downloadHeaders: Map<String, String> = emptyMap(),
    val fileSize: Long? = null,
    val checksumSha256: String = "",
    val releaseNotes: String = ""
)

data class AppLogUploadResponse(
    val id: Long,
    val accountId: String,
    val originalFileName: String,
    val fileSize: Long,
    val checksumSha256: String,
    val createdAt: String
)

data class VoiceCloneStatusResponse(
    val accountId: String,
    val status: String,
    val active: Boolean,
    val speakerId: String,
    val displayName: String,
    val sampleCount: Int,
    val lastError: String,
    val updatedAt: String?,
    val enrollmentAvailable: Boolean = false
)

data class VoiceCloneScriptItem(
    val scriptId: String,
    val text: String,
    val minDurationSeconds: Int,
    val title: String = "",
    val recordingTips: String = "",
    val targetDurationSeconds: Int = 0,
    val required: Boolean = true
)

data class VoiceCloneScriptsResponse(
    val scriptVersion: String,
    val scripts: List<VoiceCloneScriptItem>
)

data class VoiceCloneSampleUploadRequest(
    val scriptId: String,
    val text: String,
    val audioBase64: String,
    val audioFormat: String,
    val durationMs: Long
)

data class VoiceCloneUploadRequest(
    val verificationAttemptId: String,
    val collectionId: String,
    val displayName: String,
    val scriptVersion: String,
    val facePresence: VoiceCloneFacePresenceUploadRequest,
    val samples: List<VoiceCloneSampleUploadRequest>
)

data class VoiceCloneFacePresenceUploadRequest(
    val sampledFrames: Int,
    val singleFaceFrames: Int,
    val maxMissingDurationMs: Long,
    val multipleFaceDetected: Boolean,
    val maxFrameGapMs: Long = 0
)

data class ChatMessage(
    val role: MessageRole,
    val content: String
)

enum class MessageRole {
    USER,
    AI
}

data class ConversationListItem(
    val sessionId: String,
    val title: String,
    val status: String,
    val sceneType: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val conversationContinuable: Boolean? = null,
    val activeSkillId: String? = null
)

data class ConversationDetail(
    val sessionId: String,
    val title: String,
    val status: String,
    val sceneType: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null
)
