package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.finalPageForMainTab

internal class AssistantNavigationState(
    currentMainTab: FinalMainTab = FinalMainTab.Home,
    currentPage: FinalPage = FinalPage.Home,
    previousMainTab: FinalMainTab = FinalMainTab.Home
) {
    var currentMainTab by mutableStateOf(currentMainTab)
    var currentPage by mutableStateOf(currentPage)
    var previousMainTab by mutableStateOf(previousMainTab)

    fun navigateTo(page: FinalPage) {
        currentPage = page
    }

    fun setMainTab(tab: FinalMainTab) {
        currentMainTab = tab
    }

    fun applyMainTab(tab: FinalMainTab, page: FinalPage = finalPageForMainTab(tab)) {
        currentMainTab = tab
        previousMainTab = tab
        currentPage = page
    }

    fun applySubPage(previousTab: FinalMainTab, page: FinalPage) {
        previousMainTab = previousTab
        currentPage = page
    }

    fun openAssistantPage(page: FinalPage) {
        currentMainTab = FinalMainTab.Assistant
        currentPage = page
    }

    fun openAssistantSubPage(page: FinalPage) {
        previousMainTab = currentMainTab
        currentMainTab = FinalMainTab.Assistant
        currentPage = page
    }

    fun resumeSubPage(page: FinalPage) {
        previousMainTab = currentMainTab
        currentPage = page
    }

    fun restorePreviousMainTab() {
        val targetTab = previousMainTab
        currentMainTab = targetTab
        currentPage = finalPageForMainTab(targetTab)
    }

    fun restoreDialDestination(destination: DialReturnDestination) {
        currentMainTab = destination.mainTab
        previousMainTab = destination.mainTab
        currentPage = destination.page
    }

    fun goHome(resetPrevious: Boolean = true) {
        currentMainTab = FinalMainTab.Home
        currentPage = FinalPage.Home
        if (resetPrevious) {
            previousMainTab = FinalMainTab.Home
        }
    }
}

@Composable
internal fun rememberAssistantNavigationState(): AssistantNavigationState {
    return rememberSaveable(saver = AssistantNavigationStateSaver) {
        AssistantNavigationState()
    }
}

private val AssistantNavigationStateSaver = Saver<AssistantNavigationState, List<String>>(
    save = { state ->
        listOf(
            state.currentMainTab.name,
            state.currentPage.name,
            state.previousMainTab.name
        )
    },
    restore = { values ->
        AssistantNavigationState(
            currentMainTab = values.getOrNull(0).toFinalMainTabOrDefault(FinalMainTab.Home),
            currentPage = values.getOrNull(1).toFinalPageOrDefault(FinalPage.Home),
            previousMainTab = values.getOrNull(2).toFinalMainTabOrDefault(FinalMainTab.Home)
        )
    }
)

private fun String?.toFinalMainTabOrDefault(default: FinalMainTab): FinalMainTab {
    return runCatching { FinalMainTab.valueOf(orEmpty()) }.getOrDefault(default)
}

private fun String?.toFinalPageOrDefault(default: FinalPage): FinalPage {
    return runCatching { FinalPage.valueOf(orEmpty()) }.getOrDefault(default)
}
