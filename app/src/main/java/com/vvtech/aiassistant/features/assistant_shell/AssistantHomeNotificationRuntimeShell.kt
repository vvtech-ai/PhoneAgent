package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationReadEffect
import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationReadEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.model.ConversationListItem

internal class AssistantHomeNotificationRuntimeInput(
    val currentPage: FinalPage,
    val currentMainTab: FinalMainTab,
    val backendHistoryRecords: List<HistoryRecord>,
    val localCallRecords: List<FinalCallRecord>,
    val taskRecords: List<FinalTaskRecord>,
    val conversations: List<ConversationListItem>,
    val readState: AssistantHomeNotificationReadState
)

@Composable
internal fun rememberAssistantHomeNotificationRuntimeState(
    input: AssistantHomeNotificationRuntimeInput
): AssistantHomeNotificationDerivedState {
    val derivedState = remember(
        input.currentPage,
        input.backendHistoryRecords,
        input.localCallRecords,
        input.taskRecords,
        input.conversations,
        input.readState.dismissedIds
    ) {
        deriveAssistantHomeNotificationState(
            AssistantHomeNotificationDerivedStateInput(
                currentPage = input.currentPage,
                localCallRecords = input.localCallRecords,
                backendHistoryRecords = input.backendHistoryRecords,
                taskRecords = input.taskRecords,
                conversations = input.conversations,
                dismissedHomeNotificationIds = input.readState.dismissedIds
            )
        )
    }
    FinalHomeNotificationReadEffect(
        FinalHomeNotificationReadEffectArgs(
            currentMainTab = input.currentMainTab,
            pendingHomeNotifications = derivedState.pendingHomeNotifications,
            onMarkPendingHomeNotificationsRead = {
                AssistantHomeNotificationReadActions.markPendingRead(
                    readState = input.readState,
                    pendingNotifications = derivedState.pendingHomeNotifications
                )
            }
        )
    )
    return derivedState
}
