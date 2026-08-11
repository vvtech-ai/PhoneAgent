package com.vvtech.aiassistant.features.assistant_shell

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.FinalReadHomeNotificationIdsKey

internal class AssistantHomeNotificationReadState(
    dismissedIdsState: MutableState<List<String>>,
    private val persistDismissedIds: (Set<String>) -> Unit = {}
) {
    var dismissedIds by dismissedIdsState
        private set

    fun markRead(notificationIds: Iterable<String>): Boolean {
        val nextIds = (dismissedIds + notificationIds)
            .filter { it.isNotBlank() }
            .distinct()
        if (nextIds == dismissedIds) return false
        dismissedIds = nextIds
        persistDismissedIds(nextIds.toSet())
        return true
    }
}

@Composable
internal fun rememberAssistantHomeNotificationReadState(
    prefs: SharedPreferences
): AssistantHomeNotificationReadState {
    return AssistantHomeNotificationReadState(
        dismissedIdsState = rememberSaveable {
            mutableStateOf(
                prefs.getStringSet(FinalReadHomeNotificationIdsKey, emptySet())
                    .orEmpty()
                    .toList()
            )
        },
        persistDismissedIds = { ids ->
            prefs.edit()
                .putStringSet(FinalReadHomeNotificationIdsKey, ids)
                .apply()
        }
    )
}
