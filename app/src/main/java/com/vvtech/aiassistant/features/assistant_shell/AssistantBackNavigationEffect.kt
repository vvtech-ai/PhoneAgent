package com.vvtech.aiassistant.features.assistant_shell

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.finalBackTargetPage
import com.vvtech.aiassistant.features.assistant.finalPageForMainTab
import com.vvtech.aiassistant.features.assistant.isTopLevel

internal data class AssistantBackNavigationEffectArgs(
    val state: AssistantBackNavigationState,
    val callbacks: AssistantBackNavigationCallbacks
)

internal data class AssistantBackNavigationState(
    val currentPage: FinalPage,
    val previousMainTab: FinalMainTab,
    val pureVoiceMode: Boolean,
    val normalCallReturnPage: String
)

internal data class AssistantBackNavigationCallbacks(
    val nextDeferredRefreshId: (String) -> String,
    val onSingleFlowBack: (closeId: String, targetTab: FinalMainTab, targetPage: FinalPage) -> Unit,
    val onNavigateBack: (FinalPage) -> Unit
)

@Composable
internal fun AssistantBackNavigationEffect(args: AssistantBackNavigationEffectArgs) {
    val state = args.state
    val callbacks = args.callbacks
    BackHandler(enabled = !state.currentPage.isTopLevel()) {
        val pageBeforeBack = state.currentPage
        when (pageBeforeBack) {
            FinalPage.TranslateCall -> Unit
            else -> {
                val targetPage = when (pageBeforeBack) {
                    FinalPage.ContactDetail -> FinalPage.Contacts
                    FinalPage.ContactDirectoryDetail -> FinalPage.Contacts
                    FinalPage.MyIdentity -> FinalPage.Settings
                    FinalPage.SingleFlow -> {
                        val closeId = callbacks.nextDeferredRefreshId("system_back")
                        val targetTab = state.previousMainTab
                        val page = finalPageForMainTab(targetTab)
                        callbacks.onSingleFlowBack(closeId, targetTab, page)
                        page
                    }
                    else -> finalBackTargetPage(
                        currentPage = state.currentPage,
                        pureVoiceMode = state.pureVoiceMode,
                        normalCallReturnPage = state.normalCallReturnPage
                    )
                }
                if (pageBeforeBack != FinalPage.SingleFlow) {
                    callbacks.onNavigateBack(targetPage)
                }
            }
        }
    }
}
