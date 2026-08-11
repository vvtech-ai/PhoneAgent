package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.devhook.DevMockHooks
import com.vvtech.aiassistant.logging.AppFileLogger

private const val AssistantRootLogTag = "AssistantRootScreen"

internal fun logAssistantRootWarning(message: String) {
    AppFileLogger.w(AssistantRootLogTag, message)
}

internal fun assistantRootResultCallIdFallback(): String? =
    DevMockHooks.mockResultPageFallbackCallId()
