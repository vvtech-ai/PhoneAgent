package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent

internal class AgentStreamFailure(
    val failure: AgentStreamEvent.Err
) : RuntimeException(failure.message)
