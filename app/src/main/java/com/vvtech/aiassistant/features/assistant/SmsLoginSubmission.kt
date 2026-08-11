package com.vvtech.aiassistant.features.assistant

internal data class SmsLoginSubmission(
    val smsCode: String,
    val activationCode: String?,
    val loginChallenge: String?
)

internal fun buildSmsLoginSubmission(
    smsCode: String,
    activationOpen: Boolean,
    activationCode: String,
    loginChallenge: String
): SmsLoginSubmission {
    val challenge = loginChallenge.trim().takeIf { activationOpen && it.isNotBlank() }
    return SmsLoginSubmission(
        smsCode = if (challenge == null) smsCode.trim() else "",
        activationCode = activationCode.trim().takeIf { activationOpen && it.isNotBlank() },
        loginChallenge = challenge
    )
}
