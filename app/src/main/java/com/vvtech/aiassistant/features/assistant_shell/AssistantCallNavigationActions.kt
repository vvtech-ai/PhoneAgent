package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.finalBackTargetPage

internal data class AssistantNormalCallNavigationState(
    val pureVoiceMode: Boolean,
    val normalCallReturnPage: String
)

internal data class AssistantNormalCallNavigationCallbacks(
    val onPageChange: (FinalPage) -> Unit,
    val onMainTabChange: (FinalMainTab) -> Unit
)

internal fun assistantNormalCallReturnTarget(state: AssistantNormalCallNavigationState): FinalPage {
    return finalBackTargetPage(
        currentPage = FinalPage.NormalCall,
        pureVoiceMode = state.pureVoiceMode,
        normalCallReturnPage = state.normalCallReturnPage
    )
}

internal fun navigateBackFromAssistantNormalCall(
    state: AssistantNormalCallNavigationState,
    callbacks: AssistantNormalCallNavigationCallbacks
) {
    callbacks.onPageChange(assistantNormalCallReturnTarget(state))
}

internal fun navigateAfterAssistantNormalCallHangup(
    state: AssistantNormalCallNavigationState,
    callbacks: AssistantNormalCallNavigationCallbacks
) {
    val targetPage = assistantNormalCallReturnTarget(state)
    when (targetPage) {
        FinalPage.Calls -> callbacks.onMainTabChange(FinalMainTab.Calls)
        FinalPage.ContactDetail -> callbacks.onMainTabChange(FinalMainTab.Contacts)
        else -> Unit
    }
    callbacks.onPageChange(targetPage)
}
