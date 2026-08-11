package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.features.assistant_session.AssistantAgentAskQuestionsSheet

@Composable
fun AgentAskQuestionsSheet(
    payload: AskQuestionsPayload,
    onSubmit: (Map<String, Any>) -> Unit
) {
    AssistantAgentAskQuestionsSheet(
        payload = payload,
        onSubmit = onSubmit
    )
}
