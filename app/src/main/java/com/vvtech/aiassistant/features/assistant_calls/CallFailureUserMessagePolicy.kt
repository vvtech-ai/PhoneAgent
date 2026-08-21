package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun callFailureUserMessage(kind: CallFailureKind): String = when (kind) {
    CallFailureKind.SERVICE_UNAVAILABLE -> currentAppText("暂时无法接通，请稍后重试", "Unable to connect right now. Please try again later")
    CallFailureKind.BUSY -> currentAppText("对方正在通话中", "The other party is on another call")
    CallFailureKind.TEMPORARILY_UNAVAILABLE -> currentAppText("对方暂时无法接通", "The other party is temporarily unavailable")
    CallFailureKind.NETWORK -> currentAppText("网络连接异常，请检查网络后重试", "Network connection failed. Check your network and try again")
    CallFailureKind.UNKNOWN -> currentAppText("通话未接通，请稍后重试", "Call was not connected. Please try again later")
}
