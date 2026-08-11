package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.FinalDeferredTaskRefreshEffect
import com.vvtech.aiassistant.features.assistant.FinalDeferredTaskRefreshEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage

internal class AssistantTaskPageRefreshState(
    taskPageEnteredSignalState: MutableState<Long>,
    deferredRefreshSequenceState: MutableState<Long>
) {
    var taskPageEnteredSignal by taskPageEnteredSignalState
        private set

    private var deferredRefreshSequence by deferredRefreshSequenceState

    fun markTaskPageEntered() {
        taskPageEnteredSignal += 1L
    }

    fun nextDeferredRefreshId(source: String): String {
        deferredRefreshSequence += 1L
        return "$source-$deferredRefreshSequence"
    }
}

@Composable
internal fun rememberAssistantTaskPageRefreshState(): AssistantTaskPageRefreshState =
    AssistantTaskPageRefreshState(
        taskPageEnteredSignalState = remember { mutableStateOf(0L) },
        deferredRefreshSequenceState = rememberSaveable { mutableStateOf(0L) }
    )

internal class AssistantTaskDeferredRefreshShellEffectArgs(
    val taskPageEnteredSignal: Long,
    val pendingDeferredTaskRefreshCloseId: String?,
    val currentPage: FinalPage,
    val currentMainTab: FinalMainTab,
    val onClearPendingDeferredTaskRefreshCloseId: () -> Unit,
    val onRefreshTasks: (String) -> Unit,
    val onLoadConversations: (String) -> Unit
)

@Composable
internal fun AssistantTaskDeferredRefreshShellEffect(
    args: AssistantTaskDeferredRefreshShellEffectArgs
) {
    FinalDeferredTaskRefreshEffect(
        FinalDeferredTaskRefreshEffectArgs(
            taskPageEnteredSignal = args.taskPageEnteredSignal,
            pendingDeferredTaskRefreshCloseId = args.pendingDeferredTaskRefreshCloseId,
            currentPage = args.currentPage,
            currentMainTab = args.currentMainTab,
            onClearPendingDeferredTaskRefreshCloseId = args.onClearPendingDeferredTaskRefreshCloseId,
            onRefreshRealTasks = args.onRefreshTasks,
            onLoadConversations = args.onLoadConversations
        )
    )
}
