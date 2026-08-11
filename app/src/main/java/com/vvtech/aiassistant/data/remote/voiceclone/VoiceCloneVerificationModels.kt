package com.vvtech.aiassistant.data.remote.voiceclone

internal data class VoiceCloneVerificationInitRequest(
    val consentVersion: String,
    val realName: String,
    val certType: String = "IDENTITY_CARD",
    val certNo: String,
    val mobile: String? = null,
    val metaInfo: String,
    val replacementConfirmed: Boolean = false
)

internal data class VoiceCloneIdentityReplacementCheckRequest(
    val certType: String = "IDENTITY_CARD",
    val certNo: String
)

internal data class VoiceCloneIdentityReplacementCheckResponse(
    val replacementRequired: Boolean
)

internal data class VoiceCloneVerificationInitResponse(
    val attemptId: String,
    val certifyId: String,
    val status: String,
    val expiresAt: String,
    val scriptText: String?,
    val scriptVersion: String? = null,
    val scriptTemplateId: String? = null
)

internal data class VoiceCloneVerificationClientObservationRequest(
    val deviceModel: String,
    val networkType: String,
    val networkValidated: Boolean,
    val sdkCode: Int,
    val sdkSubCode: String? = null,
    val reasonCategory: String,
    val sdkElapsedMs: Long
)

internal data class VoiceCloneVerificationClientObservationResponse(
    val accepted: Boolean
)

internal data class VoiceCloneVerificationStatusResponse(
    val attemptId: String,
    val status: String,
    val expiresAt: String,
    val providerSubCode: String? = null
)

internal data class VoiceCloneCompletionActivationRequest(
    val improvementConsent: Boolean
)

internal data class VoiceCloneCollectionRequest(
    val attemptId: String,
    val previousScriptId: String? = null
)

internal data class VoiceCloneCollectionScriptResponse(
    val scriptId: String,
    val text: String,
    val minDurationSeconds: Int,
    val targetDurationSeconds: Int
)

internal data class VoiceCloneCollectionResponse(
    val collectionId: String,
    val attemptId: String,
    val scriptVersion: String,
    val script: VoiceCloneCollectionScriptResponse,
    val expiresAt: String
)
