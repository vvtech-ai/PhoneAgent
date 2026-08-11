package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal fun buildSystemPhoneCallRecord(
    plan: AssistantSystemPhoneCallUiPlan,
    occurredAtMillis: Long = System.currentTimeMillis()
): FinalCallRecord {
    val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(occurredAtMillis))
    return FinalCallRecord(
        title = "普通通话 ${plan.normalizedNumber}",
        status = "已呼出",
        meta = "$time · 00:00",
        success = true,
        occurredAtMillis = occurredAtMillis,
        phoneNumber = plan.normalizedNumber,
        startTimeText = time,
        endTimeText = time,
        durationText = "00:00",
        resultText = "已拉起系统电话",
        callKind = DialCallKind.NORMAL
    )
}
