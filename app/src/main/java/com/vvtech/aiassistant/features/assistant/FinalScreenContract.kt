package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.CubicBezierEasing
import com.vvtech.aiassistant.core.model.TranslationCallStartResponse
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
internal enum class FinalMainTab {
    Home,
    Contacts,
    Assistant,
    Calls,
    Tasks,
    Settings
}

internal fun TranslationCallStartResponse.toStatusResponse(
    updatedAt: String = ""
): TranslationCallStatusResponse {
    return TranslationCallStatusResponse(
        callId = callId,
        callState = callState,
        translationState = translationState,
        provider = provider,
        callerDetectedLanguage = callerDetectedLanguage,
        calleeDetectedLanguage = calleeDetectedLanguage,
        effectiveCallerToCalleeVoice = effectiveCallerToCalleeVoice,
        voiceCapability = voiceCapability,
        subtitleItems = emptyList(),
        passthroughActive = passthroughActive,
        passthroughReason = passthroughReason,
        statusMessage = statusMessage,
        updatedAt = updatedAt
    )
}

internal fun buildPendingTranslationStatus(
    provider: String,
    callState: String = "DIALING",
    translationState: String = "LANGUAGE_DETECTING",
    statusMessage: String,
    voiceCapability: String = "SOURCE_VOICE_MIMIC_ONLY"
): TranslationCallStatusResponse {
    return TranslationCallStatusResponse(
        callId = "",
        callState = callState,
        translationState = translationState,
        provider = provider,
        callerDetectedLanguage = "",
        calleeDetectedLanguage = "",
        effectiveCallerToCalleeVoice = "",
        voiceCapability = voiceCapability,
        subtitleItems = emptyList(),
        passthroughActive = false,
        passthroughReason = null,
        statusMessage = statusMessage,
        updatedAt = ""
    )
}

internal enum class FinalPage {
    Home,
    Contacts,
    ContactDetail,
    ContactDirectoryDetail,
    Assistant,
    SingleFlow,
    Calls,
    Tasks,
    Settings,
    SipAccountSettings,
    DeveloperTools,
    OutboundNumberEdit,
    RealtimeProviderSettings,
    RealtimeCallVoiceSettings,
    TranslationProviderSettings,
    OriginalAudioSettings,
    VoiceIdentitySettings,
    VoiceCloneSettings,
    ContactMethods,
    ContactMethodEdit,
    MyIdentity,
    Clarify,
    Confirm,
    AiCall,
    Result,
    AgentCallDetail,
    NormalCall,
    TranslateCall
}

internal enum class ComposerMode {
    Voice,
    Text
}

internal enum class DeveloperDataMode {
    Filled,
    Empty
}

internal val FinalMotionEase = CubicBezierEasing(0.2f, 0.75f, 0.24f, 1f)
internal val FinalFadeEase = CubicBezierEasing(0.25f, 0.10f, 0.25f, 1f)

internal const val FinalPageInDurationMs = 260
internal const val FinalSubPageInDurationMs = 280
internal const val FinalMotionDurationMs = 420
internal const val FinalFadeDurationMs = 240
internal const val FinalThreadFadeDurationMs = 280
internal val UseSingleFlowConversationInFinal = true
internal const val FinalPrefsName = "index9_native_screen"
internal const val FinalPersonalInfoListKey = "personal_info_list"
internal const val FinalMaxPersonalInfoCount = 5
internal const val FinalPureVoiceModeKey = "pure_voice_mode"
internal const val FinalVoiceLanguageCodeKey = VoiceLanguageCodeKey
internal const val FinalVoiceCloneGuideDisabledKey = "voice_clone_guide_disabled"
internal const val FinalTrustedCalleeAuthorizedKey = "trusted_callee_authorized"
internal const val FinalTrustedCalleeGuideSeenKey = "trusted_callee_guide_seen"
internal const val FinalTrustedCalleeGuideDisabledKey = "trusted_callee_guide_disabled"
internal const val FinalTrustedCalleeSdkGuideSeenKey = "trusted_callee_sdk_guide_seen"
internal const val FinalReadHomeNotificationIdsKey = "read_home_notification_ids"
internal const val FinalTranslationQwenVoiceKey = "translation_qwen_voice"
internal const val FinalTranslationQwenCallerLanguageKey = "translation_qwen_caller_language"
internal const val FinalTranslationQwenCalleeLanguageKey = "translation_qwen_callee_language"
internal const val FinalDeveloperModeEnabledKey = "developer_mode_enabled"
internal const val FinalOtaForceUpdateRequiredKey = "ota_force_update_required"
internal const val FinalOtaLastStartupCheckDateKey = "ota_last_startup_check_date"
internal const val FinalDeveloperModeUnlockCode = "20142014"
internal const val FinalDefaultPureVoiceMode = true

internal val FinalTopLevelPages = setOf(
    FinalPage.Home,
    FinalPage.Contacts,
    FinalPage.Assistant,
    FinalPage.Calls,
    FinalPage.Tasks,
    FinalPage.Settings
)

internal fun FinalPage.isTopLevel(): Boolean = this in FinalTopLevelPages

internal fun shouldRunStartupOtaCheck(
    forceUpdateRequired: Boolean,
    lastCheckDate: String?,
    today: String
): Boolean = forceUpdateRequired || lastCheckDate != today

internal fun otaForceUpdateRequiredFromResponse(
    hasUpdate: Boolean,
    forceUpdate: Boolean
): Boolean = hasUpdate && forceUpdate

internal fun FinalPage.topLevelTabIndex(): Int? = when (this) {
    FinalPage.Home -> 0
    FinalPage.Contacts -> 1
    FinalPage.Assistant -> 2
    FinalPage.Calls -> 3
    FinalPage.Tasks -> 4
    FinalPage.Settings -> 5
    else -> null
}

internal enum class DialCallKind {
    AGENT,
    NORMAL,
    TRANSLATION
}

internal data class FinalCallRecord(
    val title: String,
    val status: String,
    val meta: String,
    val success: Boolean,
    val occurredAtMillis: Long? = null,
    val phoneNumber: String = "",
    val dateText: String = "",
    val startTimeText: String = "",
    val endTimeText: String = "",
    val durationText: String = "",
    val resultText: String = "",
    val transcript: List<TranscriptLine> = emptyList(),
    val taskId: String = "",
    val callId: String = "",
    val callKind: DialCallKind = DialCallKind.AGENT,
    val dialCountryIso: String = "",
    val callerLanguageCode: String = "",
    val calleeLanguageCode: String = ""
)

internal data class FinalTaskRecord(
    val title: String,
    val status: String,
    val detail: String,
    val sceneType: String? = null,
    val sourceText: String = "",
    val notificationId: String? = null,
    val startedAt: String = "",
    val scheduledAt: String = ""
)

internal data class FinalContactRecord(
    val name: String,
    val phone: String,
    val systemDialPhone: String = phone,
    val hint: String
)

internal data class FinalOption(
    val id: String,
    val title: String,
    val subtitle: String,
    val userLabel: String = title
)

internal enum class ContactEditMode {
    Add,
    Edit
}
