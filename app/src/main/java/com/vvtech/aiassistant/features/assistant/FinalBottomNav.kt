package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_ui.AssistantBottomNavigationBar
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage

@Composable
internal fun FinalBottomTabBarCompat(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    onDialClick: () -> Unit = {},
    hidden: Boolean = false,
    taskBadgeCount: Int = 0,
    appLanguage: AppLanguage = AppLanguage.English
) {
    AssistantBottomNavigationBar(
        selected = selected,
        onSelect = onSelect,
        onDialClick = onDialClick,
        hidden = hidden,
        taskBadgeCount = taskBadgeCount,
        appLanguage = appLanguage
    )
}

@Composable
internal fun FinalBottomTabBar(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    onDialClick: () -> Unit = {},
    hidden: Boolean = false,
    taskBadgeCount: Int = 0,
    appLanguage: AppLanguage = AppLanguage.English
) {
    AssistantBottomNavigationBar(
        selected = selected,
        onSelect = onSelect,
        onDialClick = onDialClick,
        hidden = hidden,
        taskBadgeCount = taskBadgeCount,
        appLanguage = appLanguage
    )
}
