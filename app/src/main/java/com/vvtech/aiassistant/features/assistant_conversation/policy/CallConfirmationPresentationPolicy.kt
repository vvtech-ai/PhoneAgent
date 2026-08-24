package com.vvtech.aiassistant.features.assistant_conversation.policy

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

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
            target.isNotBlank() -> currentAppText(
                "任务确认完毕，现在帮您拨打${target}的电话...",
                "Details confirmed. Calling $target now..."
            )
            fallbackText.isNotBlank() -> fallbackText.trim()
            else -> currentAppText(
                "任务确认完毕，现在帮您拨打电话...",
                "Details confirmed. Calling now..."
            )
        }
    }
}
