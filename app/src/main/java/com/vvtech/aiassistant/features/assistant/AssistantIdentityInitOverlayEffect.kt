package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.vvtech.aiassistant.account.AccountIdentityProvider

internal data class AssistantIdentityInitOverlayEffectArgs(
    val currentPage: FinalPage,
    val previousMainTab: FinalMainTab,
    val identityInitOverlayVisible: Boolean,
    val runtime: AssistantContactRuntimeController,
    val onNavigateFallback: (FinalMainTab, FinalPage) -> Unit
)

@Composable
internal fun FinalIdentityInitOverlayEffect(args: AssistantIdentityInitOverlayEffectArgs) {
    LaunchedEffect(args.currentPage, args.runtime.identityNeedsInit, args.identityInitOverlayVisible) {
        if (args.identityInitOverlayVisible && !args.runtime.identityNeedsInit) {
            args.runtime.dismissIdentityInitOverlay()
            return@LaunchedEffect
        }
        if (args.currentPage == FinalPage.Home &&
            args.runtime.identityNeedsInit &&
            !args.identityInitOverlayVisible &&
            !args.runtime.identityInitSkippedThisSession &&
            AccountIdentityProvider.accountId.isNotBlank()
        ) {
            val fallbackTab = if (args.previousMainTab == FinalMainTab.Assistant) {
                FinalMainTab.Home
            } else {
                args.previousMainTab
            }
            args.runtime.identityOverlayError = null
            args.onNavigateFallback(fallbackTab, finalPageForIdentityInitFallback(fallbackTab))
            args.runtime.showIdentityInitOverlay()
        }
    }
}
