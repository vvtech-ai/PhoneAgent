package com.vvtech.aiassistant.features.assistant_conversation.policy

import com.vvtech.aiassistant.core.model.CallSpecPayload

/**
 * Keeps the live MAKE_CALL_REQUEST message and its durable timeline projection identical.
 */
internal object CallConfirmationPresentationPolicy {
    fun displayText(
        callSpec: CallSpecPayload?,
        fallbackText: String = "",
    ): String {
        val target = callSpec?.targetName?.trim().orEmpty()
        return when {
            target.isNotBlank() -> "任务确认完毕，现在帮您拨打${target}的电话..."
            fallbackText.isNotBlank() -> fallbackText.trim()
            else -> "任务确认完毕，现在帮您拨打电话..."
        }
    }
}
