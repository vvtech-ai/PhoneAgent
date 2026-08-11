package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_ui.AssistantBottomNavigationBar

@Composable
internal fun FinalBottomTabBarCompat(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    onDialClick: () -> Unit = {},
    hidden: Boolean = false,
    taskBadgeCount: Int = 0
) {
    AssistantBottomNavigationBar(
        selected = selected,
        onSelect = onSelect,
        onDialClick = onDialClick,
        hidden = hidden,
        taskBadgeCount = taskBadgeCount
    )
}

@Composable
internal fun FinalBottomTabBar(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    onDialClick: () -> Unit = {},
    hidden: Boolean = false,
    taskBadgeCount: Int = 0
) {
    AssistantBottomNavigationBar(
        selected = selected,
        onSelect = onSelect,
        onDialClick = onDialClick,
        hidden = hidden,
        taskBadgeCount = taskBadgeCount
    )
}
