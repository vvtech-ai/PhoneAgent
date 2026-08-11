package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.domain.call.CallFailureKind

internal fun callFailureUserMessage(kind: CallFailureKind): String = when (kind) {
    CallFailureKind.SERVICE_UNAVAILABLE -> "暂时无法接通，请稍后重试"
    CallFailureKind.BUSY -> "对方正在通话中"
    CallFailureKind.TEMPORARILY_UNAVAILABLE -> "对方暂时无法接通"
    CallFailureKind.NETWORK -> "网络连接异常，请检查网络后重试"
    CallFailureKind.UNKNOWN -> "通话未接通，请稍后重试"
}
