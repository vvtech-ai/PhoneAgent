package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import kotlinx.coroutines.delay

internal data class FinalAccountIdentityEffectArgs(
    val activeAccountId: String,
    val mockLoggedIn: Boolean,
    val onLoadCallRecordsForAccount: (String) -> Unit,
    val onClearCallRecordsForCurrentAccount: () -> Unit,
    val onAccountIdentityChanged: (Boolean) -> Unit
)

@Composable
internal fun FinalAccountIdentityEffect(args: FinalAccountIdentityEffectArgs) {
    LaunchedEffect(args.activeAccountId, args.mockLoggedIn) {
        if (args.mockLoggedIn && args.activeAccountId.isNotBlank()) {
            args.onLoadCallRecordsForAccount(args.activeAccountId)
            args.onAccountIdentityChanged(true)
        } else {
            args.onClearCallRecordsForCurrentAccount()
            args.onAccountIdentityChanged(false)
        }
    }
}

internal data class FinalHomeNotificationReadEffectArgs(
    val currentMainTab: FinalMainTab,
    val pendingHomeNotifications: List<FinalHomeNotificationItem>,
    val onMarkPendingHomeNotificationsRead: () -> Unit
)

@Composable
internal fun FinalHomeNotificationReadEffect(args: FinalHomeNotificationReadEffectArgs) {
    LaunchedEffect(args.currentMainTab, args.pendingHomeNotifications) {
        if (args.currentMainTab == FinalMainTab.Tasks && args.pendingHomeNotifications.isNotEmpty()) {
            args.onMarkPendingHomeNotificationsRead()
        }
    }
}

internal data class FinalDeferredTaskRefreshEffectArgs(
    val taskPageEnteredSignal: Long,
    val pendingDeferredTaskRefreshCloseId: String?,
    val currentPage: FinalPage,
    val currentMainTab: FinalMainTab,
    val onClearPendingDeferredTaskRefreshCloseId: () -> Unit,
    val onRefreshRealTasks: (String) -> Unit,
    val onLoadConversations: (String) -> Unit
)

@Composable
internal fun FinalDeferredTaskRefreshEffect(args: FinalDeferredTaskRefreshEffectArgs) {
    val latestArgs by rememberUpdatedState(args)

    LaunchedEffect(args.taskPageEnteredSignal, args.pendingDeferredTaskRefreshCloseId) {
        val closeId = args.pendingDeferredTaskRefreshCloseId ?: return@LaunchedEffect
        if (latestArgs.currentPage != FinalPage.Tasks || latestArgs.currentMainTab != FinalMainTab.Tasks) {
            return@LaunchedEffect
        }
        delay(800L)
        if (
            latestArgs.pendingDeferredTaskRefreshCloseId != closeId ||
            latestArgs.currentPage != FinalPage.Tasks ||
            latestArgs.currentMainTab != FinalMainTab.Tasks
        ) {
            return@LaunchedEffect
        }
        latestArgs.onClearPendingDeferredTaskRefreshCloseId()
        latestArgs.onRefreshRealTasks("deferred_visible_close:$closeId")
        latestArgs.onLoadConversations("deferred_visible_close:$closeId")
    }
}

internal data class FinalTrustedCalleeGuideEffectArgs(
    val mockLoggedIn: Boolean,
    val trustedCalleeStartupReady: Boolean,
    val currentPage: FinalPage,
    val trustedCalleeAuthorized: Boolean,
    val trustedCalleeGuideSeen: Boolean,
    val trustedCalleeGuideDisabled: Boolean,
    val trustedCalleeGuideShownThisSession: Boolean,
    val onShowTrustedCalleeGuide: () -> Unit
)

@Composable
internal fun FinalTrustedCalleeGuideEffect(args: FinalTrustedCalleeGuideEffectArgs) {
    val latestArgs by rememberUpdatedState(args)

    LaunchedEffect(
        args.mockLoggedIn,
        args.trustedCalleeStartupReady,
        args.currentPage,
        args.trustedCalleeAuthorized,
        args.trustedCalleeGuideSeen,
        args.trustedCalleeGuideDisabled,
        args.trustedCalleeGuideShownThisSession
    ) {
        if (
            args.mockLoggedIn &&
            args.trustedCalleeStartupReady &&
            args.currentPage == FinalPage.Home &&
            !args.trustedCalleeAuthorized &&
            !args.trustedCalleeGuideSeen &&
            !args.trustedCalleeGuideDisabled &&
            !args.trustedCalleeGuideShownThisSession
        ) {
            delay(300L)
            if (latestArgs.currentPage == FinalPage.Home && !latestArgs.trustedCalleeGuideShownThisSession) {
                latestArgs.onShowTrustedCalleeGuide()
            }
        }
    }
}

internal data class FinalAiThinkingEffectArgs(
    val aiThinking: Boolean,
    val onAiThinkingChange: (Boolean) -> Unit,
    val onAiReplyVisibleChange: (Boolean) -> Unit
)

@Composable
internal fun FinalAiThinkingEffect(args: FinalAiThinkingEffectArgs) {
    LaunchedEffect(args.aiThinking) {
        if (args.aiThinking) {
            delay(850L)
            args.onAiThinkingChange(false)
            args.onAiReplyVisibleChange(true)
        }
    }
}

internal data class FinalRestaurantConfirmEffectArgs(
    val confirmingRestaurantId: String?,
    val selectedRestaurantId: String?,
    val onRestaurantConfirmedChange: (Boolean) -> Unit,
    val onConfirmingRestaurantIdChange: (String?) -> Unit
)

@Composable
internal fun FinalRestaurantConfirmEffect(args: FinalRestaurantConfirmEffectArgs) {
    val latestArgs by rememberUpdatedState(args)

    LaunchedEffect(args.confirmingRestaurantId) {
        val pendingId = args.confirmingRestaurantId ?: return@LaunchedEffect
        delay(780L)
        if (latestArgs.confirmingRestaurantId == pendingId && latestArgs.selectedRestaurantId == pendingId) {
            latestArgs.onRestaurantConfirmedChange(true)
        }
        if (latestArgs.confirmingRestaurantId == pendingId) {
            latestArgs.onConfirmingRestaurantIdChange(null)
        }
    }
}

internal data class FinalFallbackConfirmEffectArgs(
    val confirmingFallbackId: String?,
    val selectedFallbackIds: List<String>,
    val restaurantConfirmed: Boolean,
    val onFallbackConfirmedChange: (Boolean) -> Unit,
    val onConfirmingFallbackIdChange: (String?) -> Unit
)

@Composable
internal fun FinalFallbackConfirmEffect(args: FinalFallbackConfirmEffectArgs) {
    val latestArgs by rememberUpdatedState(args)

    LaunchedEffect(args.confirmingFallbackId) {
        val pendingId = args.confirmingFallbackId ?: return@LaunchedEffect
        delay(780L)
        if (
            latestArgs.confirmingFallbackId == pendingId &&
            latestArgs.selectedFallbackIds.isNotEmpty() &&
            latestArgs.restaurantConfirmed
        ) {
            latestArgs.onFallbackConfirmedChange(true)
        }
        if (latestArgs.confirmingFallbackId == pendingId) {
            latestArgs.onConfirmingFallbackIdChange(null)
        }
    }
}
