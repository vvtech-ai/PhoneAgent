package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_session.AssistantSessionResumeRole
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionResumeStep

internal fun AssistantSessionResumeStep.toClarificationStep(): ClarificationStep {
    return ClarificationStep(
        role = when (role) {
            AssistantSessionResumeRole.Assistant -> VoiceRole.Assistant
            AssistantSessionResumeRole.User -> VoiceRole.User
        },
        text = text,
        status = status,
        callResult = callResult,
        batchCallResult = batchCallResult
    )
}
