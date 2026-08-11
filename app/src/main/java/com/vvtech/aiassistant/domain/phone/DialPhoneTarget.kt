package com.vvtech.aiassistant.domain.phone

internal enum class DialPhoneNumberType {
    CHINA_MOBILE,
    CHINA_FIXED_LINE,
    CHINA_LOCAL_OR_SHORT,
    CHINA_SERVICE,
    CHINA_EMERGENCY,
    INTERNATIONAL
}

internal data class DialPhoneTarget(
    val displayNumber: String,
    val canonicalNumber: String,
    val networkDialNumber: String,
    val systemDialNumber: String,
    val type: DialPhoneNumberType,
    val postConnectDtmf: String = ""
) {
    val systemOnly: Boolean
        get() = type == DialPhoneNumberType.CHINA_EMERGENCY

    val chinaDomestic: Boolean
        get() = type != DialPhoneNumberType.INTERNATIONAL
}

internal sealed interface DialPhoneTargetResult {
    data class Ready(val target: DialPhoneTarget) : DialPhoneTargetResult
    data class Invalid(val message: String) : DialPhoneTargetResult
}
