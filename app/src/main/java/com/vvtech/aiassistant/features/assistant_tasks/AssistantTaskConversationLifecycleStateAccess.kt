package com.vvtech.aiassistant.features.assistant_tasks

internal data class AssistantTaskConversationLifecycleStateAccess(
    val taskRestoreStateHolder: TaskRestoreStateHolder,
    val exitResetStateReader: TaskConversationExitResetStateReader,
    val backgroundPauseStateHolder: TaskConversationBackgroundPauseStateHolder,
    val listLoadStateHolder: TaskConversationListLoadStateHolder
)
