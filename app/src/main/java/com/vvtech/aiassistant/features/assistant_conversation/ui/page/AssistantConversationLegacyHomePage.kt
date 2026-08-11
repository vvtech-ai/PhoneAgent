package com.vvtech.aiassistant.features.assistant_conversation.ui.page

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalHomeAssistantPage
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeAgentSheetState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeComposerState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeNotificationState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomePageCallbacks
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeTaskState
import com.vvtech.aiassistant.features.assistant_home.AssistantHomeConfigRoute

@Composable
internal fun AssistantConversationLegacyHomePage(
    composerState: AssistantHomeComposerState,
    taskState: AssistantHomeTaskState,
    agentSheetState: AssistantHomeAgentSheetState,
    notificationState: AssistantHomeNotificationState,
    callbacks: AssistantHomePageCallbacks
) {
    AssistantHomeConfigRoute(
        visible = true,
        onQuickVoiceEntry = callbacks.shell.onQuickVoiceEntry,
        onOpenTranslateDial = callbacks.shell.onOpenTranslateDial,
        onBlockOffline = callbacks.shell.onBlockOffline
    ) { homeConfig, onCardEntry ->
        FinalHomeAssistantPage(
            composerState = composerState,
            taskState = taskState,
            agentSheetState = agentSheetState,
            notificationState = notificationState,
            homeConfig = homeConfig,
            onHomeCardEntry = onCardEntry,
            callbacks = callbacks
        )
    }
}
