package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal enum class VoiceCloneEnrollmentStep {
    CONSENT,
    IDENTITY,
    VERIFYING,
    CLONING,
    VERIFIED
}

internal enum class VoiceCloneVerificationPhase {
    SDK_COLLECTING,
    RESULT_CHECKING
}

internal enum class VoiceCloneIdentityFieldKind {
    REAL_NAME,
    ID_CARD
}

internal data class VoiceCloneIdentityPrefill(
    val name: String,
    val verified: Boolean
)

internal data class VoiceCloneEnrollmentCollection(
    val collectionId: String,
    val scriptId: String,
    val scriptText: String,
    val minDurationSeconds: Int,
    val targetDurationSeconds: Int
)

internal data class VoiceCloneEnrollmentState(
    val step: VoiceCloneEnrollmentStep = VoiceCloneEnrollmentStep.CONSENT,
    val agreementAccepted: Boolean = false,
    val realName: String = "",
    val idCardNumber: String = "",
    val realNameMasked: Boolean = false,
    val idCardNumberMasked: Boolean = false,
    val attemptId: String? = null,
    val certifyId: String? = null,
    val scriptText: String? = null,
    val scriptVersion: String? = null,
    val scriptTemplateId: String? = null,
    val collection: VoiceCloneEnrollmentCollection? = null,
    val verificationPhase: VoiceCloneVerificationPhase =
        VoiceCloneVerificationPhase.SDK_COLLECTING,
    val replacementConfirmationRequired: Boolean = false,
    val replacementConfirmed: Boolean = false,
    val busy: Boolean = false,
    val errorMessage: String? = null
) {
    val displayRealName: String
        get() = if (realNameMasked) maskIdentityName(realName) else realName

    val displayIdCardNumber: String
        get() = if (idCardNumberMasked) maskIdentityCardNumber(idCardNumber) else idCardNumber
}

internal fun VoiceCloneEnrollmentState.canStartVerification(): Boolean =
    step == VoiceCloneEnrollmentStep.IDENTITY && !busy

internal fun shouldContinueVoiceCloneStatusPolling(step: VoiceCloneEnrollmentStep): Boolean =
    step == VoiceCloneEnrollmentStep.VERIFYING

internal sealed interface VoiceCloneEnrollmentEvent {
    data class AgreementChanged(val accepted: Boolean) : VoiceCloneEnrollmentEvent
    object ContinueAfterConsent : VoiceCloneEnrollmentEvent
    data class IdentityChanged(val realName: String, val idCardNumber: String) : VoiceCloneEnrollmentEvent
    data class IdentityEditStarted(
        val field: VoiceCloneIdentityFieldKind
    ) : VoiceCloneEnrollmentEvent
    object ReplacementCheckRequested : VoiceCloneEnrollmentEvent
    object ReplacementNotRequired : VoiceCloneEnrollmentEvent
    object ReplacementConfirmationRequired : VoiceCloneEnrollmentEvent
    object ReplacementConfirmed : VoiceCloneEnrollmentEvent
    object ReplacementConfirmationDismissed : VoiceCloneEnrollmentEvent
    object VerificationRequested : VoiceCloneEnrollmentEvent
    data class VerificationInitialized(
        val attemptId: String,
        val certifyId: String,
        val scriptText: String,
        val scriptVersion: String? = null,
        val scriptTemplateId: String? = null
    ) : VoiceCloneEnrollmentEvent
    data class SdkFinished(val diagnosis: VoiceCloneSdkDiagnosis) : VoiceCloneEnrollmentEvent
    data class ServerStatus(
        val status: String,
        val providerSubCode: String? = null
    ) : VoiceCloneEnrollmentEvent
    data class CloneAccepted(val status: String) : VoiceCloneEnrollmentEvent
    data class InputRejected(val message: String) : VoiceCloneEnrollmentEvent
    data class Failed(val message: String) : VoiceCloneEnrollmentEvent
    object Exit : VoiceCloneEnrollmentEvent
}

internal object VoiceCloneEnrollmentReducer {
    fun reduce(
        state: VoiceCloneEnrollmentState,
        event: VoiceCloneEnrollmentEvent
    ): VoiceCloneEnrollmentState = when (event) {
        is VoiceCloneEnrollmentEvent.AgreementChanged -> state.copy(
            agreementAccepted = event.accepted,
            errorMessage = null
        )

        VoiceCloneEnrollmentEvent.ContinueAfterConsent -> if (state.agreementAccepted) {
            state.copy(step = VoiceCloneEnrollmentStep.IDENTITY, errorMessage = null)
        } else {
            state
        }

        is VoiceCloneEnrollmentEvent.IdentityChanged -> state.copy(
            realName = event.realName,
            idCardNumber = event.idCardNumber,
            replacementConfirmationRequired = false,
            replacementConfirmed = false,
            errorMessage = null
        )

        is VoiceCloneEnrollmentEvent.IdentityEditStarted -> when (event.field) {
            VoiceCloneIdentityFieldKind.REAL_NAME -> if (state.realNameMasked) {
                state.copy(
                    realName = "",
                    realNameMasked = false,
                    replacementConfirmationRequired = false,
                    replacementConfirmed = false,
                    errorMessage = null
                )
            } else {
                state
            }

            VoiceCloneIdentityFieldKind.ID_CARD -> if (state.idCardNumberMasked) {
                state.copy(
                    idCardNumber = "",
                    idCardNumberMasked = false,
                    replacementConfirmationRequired = false,
                    replacementConfirmed = false,
                    errorMessage = null
                )
            } else {
                state
            }
        }

        VoiceCloneEnrollmentEvent.ReplacementCheckRequested ->
            state.copy(busy = true, errorMessage = null)

        VoiceCloneEnrollmentEvent.ReplacementNotRequired -> state.copy(
            busy = false,
            replacementConfirmationRequired = false,
            replacementConfirmed = false
        )

        VoiceCloneEnrollmentEvent.ReplacementConfirmationRequired -> state.copy(
            busy = false,
            replacementConfirmationRequired = true,
            replacementConfirmed = false
        )

        VoiceCloneEnrollmentEvent.ReplacementConfirmed -> state.copy(
            busy = false,
            replacementConfirmationRequired = false,
            replacementConfirmed = true
        )

        VoiceCloneEnrollmentEvent.ReplacementConfirmationDismissed -> state.copy(
            busy = false,
            replacementConfirmationRequired = false,
            replacementConfirmed = false
        )

        VoiceCloneEnrollmentEvent.VerificationRequested -> state.copy(busy = true, errorMessage = null)

        is VoiceCloneEnrollmentEvent.VerificationInitialized -> state.copy(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = event.attemptId,
            certifyId = event.certifyId,
            scriptText = event.scriptText,
            scriptVersion = event.scriptVersion,
            scriptTemplateId = event.scriptTemplateId,
            verificationPhase = VoiceCloneVerificationPhase.SDK_COLLECTING,
            busy = true,
            errorMessage = null
        )

        is VoiceCloneEnrollmentEvent.SdkFinished ->
            if (VoiceCloneSdkResultPolicy.requiresServerQuery(event.diagnosis.code)) {
                state.copy(
                    step = VoiceCloneEnrollmentStep.VERIFYING,
                    verificationPhase = VoiceCloneVerificationPhase.RESULT_CHECKING,
                    busy = true,
                    errorMessage = null
                )
            } else {
                resetVerificationWithError(
                    state,
                    VoiceCloneSdkFailureMessagePolicy.messageFor(event.diagnosis)
                )
            }

        is VoiceCloneEnrollmentEvent.ServerStatus -> when (event.status.uppercase()) {
            "PASS" -> state.copy(step = VoiceCloneEnrollmentStep.CLONING, busy = true, errorMessage = null)
            "INIT", "PROCESSING" -> state.copy(
                step = VoiceCloneEnrollmentStep.VERIFYING,
                verificationPhase = VoiceCloneVerificationPhase.RESULT_CHECKING,
                busy = true
            )
            else -> resetVerificationWithError(state, serverFailureMessage(event.providerSubCode))
        }

        is VoiceCloneEnrollmentEvent.CloneAccepted ->
            if (event.status.uppercase() in ACCEPTED_CLONE_STATUSES) {
                state.copy(
                    step = VoiceCloneEnrollmentStep.VERIFIED,
                    collection = null,
                    busy = false,
                    errorMessage = null
                )
            } else {
                resetWithError(currentAppText(
                    "声音克隆未被服务端接受，请重新开始。",
                    "The voice clone was not accepted by the server. Please start again."
                ))
            }
        is VoiceCloneEnrollmentEvent.InputRejected -> state.copy(busy = false, errorMessage = event.message)
        is VoiceCloneEnrollmentEvent.Failed -> resetVerificationWithError(state, event.message)
        VoiceCloneEnrollmentEvent.Exit -> VoiceCloneEnrollmentState()
    }

    private fun resetWithError(message: String) = VoiceCloneEnrollmentState(errorMessage = message)

    private fun resetVerificationWithError(
        state: VoiceCloneEnrollmentState,
        message: String
    ): VoiceCloneEnrollmentState {
        if (state.realName.isBlank() || state.idCardNumber.isBlank()) {
            return resetWithError(message)
        }
        return state.copy(
            step = VoiceCloneEnrollmentStep.IDENTITY,
            attemptId = null,
            certifyId = null,
            scriptText = null,
            scriptVersion = null,
            scriptTemplateId = null,
            collection = null,
            verificationPhase = VoiceCloneVerificationPhase.SDK_COLLECTING,
            realNameMasked = true,
            idCardNumberMasked = true,
            replacementConfirmationRequired = false,
            replacementConfirmed = false,
            busy = false,
            errorMessage = message
        )
    }

    private fun serverFailureMessage(providerSubCode: String?): String = when (providerSubCode) {
        "205" -> currentAppText(
            "活体检测存在风险，请确认由本人在正常设备环境下重新认证。",
            "Liveness verification detected a risk. Make sure you are verifying yourself on a normal device, then try again."
        )
        "220" -> currentAppText(
            "跟读内容未完整识别，请在安静环境中连续读完整句话后重新认证。",
            "The read-aloud content was not fully recognized. Try again in a quiet place and read the full sentence continuously."
        )
        else -> currentAppText("实名认证未通过，请重新开始。", "Real-name verification failed. Please start again.")
    }

    private val ACCEPTED_CLONE_STATUSES = setOf("READY", "PROCESSING")
}

internal fun maskIdentityName(value: String): String {
    val normalized = value.trim()
    if (normalized.isEmpty()) return ""
    if (normalized.length == 1) return "*"
    return normalized.first() + "*".repeat(normalized.length - 1)
}

internal fun maskIdentityCardNumber(value: String): String {
    val normalized = value.trim()
    if (normalized.length <= 7) return "*".repeat(normalized.length)
    return normalized.take(3) +
        "*".repeat(normalized.length - 7) +
        normalized.takeLast(4)
}

internal fun requiresIdentityNameReplacement(
    verifiedName: String?,
    candidateName: String
): Boolean {
    val normalizedVerified = verifiedName?.trim().orEmpty()
    return normalizedVerified.isNotEmpty() && normalizedVerified != candidateName.trim()
}
