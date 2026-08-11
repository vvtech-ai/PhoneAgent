package com.vvtech.aiassistant.domain.call

import java.io.IOException

enum class CallFailureKind {
    SERVICE_UNAVAILABLE,
    BUSY,
    TEMPORARILY_UNAVAILABLE,
    NETWORK,
    UNKNOWN
}

object CallFailureClassifier {
    fun fromSip(
        sipMethod: String?,
        statusCode: Int?
    ): CallFailureKind {
        if (sipMethod.isNullOrBlank() || statusCode == null) {
            return CallFailureKind.UNKNOWN
        }
        return when {
            statusCode in 500..599 -> CallFailureKind.SERVICE_UNAVAILABLE
            statusCode == 486 || statusCode == 600 -> CallFailureKind.BUSY
            statusCode == 408 || statusCode == 480 ->
                CallFailureKind.TEMPORARILY_UNAVAILABLE
            else -> CallFailureKind.UNKNOWN
        }
    }

    fun fromThrowable(error: Throwable): CallFailureKind =
        if (error is IOException) CallFailureKind.NETWORK else CallFailureKind.UNKNOWN
}
