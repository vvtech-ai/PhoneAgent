package com.vvtech.aiassistant.features.assistant_conversation.policy

import com.vvtech.aiassistant.core.model.CallSpecPayload

internal object CallConfirmationIdentityPolicy {

    fun representsSameConfirmation(
        leftSpec: CallSpecPayload?,
        leftToolCallId: String?,
        rightSpec: CallSpecPayload?,
        rightToolCallId: String?,
    ): Boolean {
        if (leftSpec == null || rightSpec == null) return false
        val leftIdentity = leftToolCallId?.trim()?.takeIf(String::isNotBlank)
        val rightIdentity = rightToolCallId?.trim()?.takeIf(String::isNotBlank)
        return when {
            leftIdentity != null && rightIdentity != null -> leftIdentity == rightIdentity
            leftIdentity != null || rightIdentity != null -> false
            else -> leftSpec == rightSpec
        }
    }
}
