package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.AssistantAuthRuntimeController
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeController
import com.vvtech.aiassistant.features.assistant.AssistantIdentityInitOverlayEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalIdentityInitOverlayEffect
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTrustedCalleeRuntimeEffect

internal data class AssistantIdentityInitOverlayShellEffectArgs(
    val currentPage: FinalPage,
    val previousMainTab: FinalMainTab,
    val identityInitOverlayVisible: Boolean,
    val runtime: AssistantContactRuntimeController,
    val onNavigateFallback: (FinalMainTab, FinalPage) -> Unit
)

internal data class AssistantTrustedCalleeRuntimeShellEffectArgs(
    val currentPage: FinalPage,
    val runtime: AssistantAuthRuntimeController
)

@Composable
internal fun AssistantIdentityInitOverlayShellEffect(args: AssistantIdentityInitOverlayShellEffectArgs) {
    FinalIdentityInitOverlayEffect(
        AssistantIdentityInitOverlayEffectArgs(
            currentPage = args.currentPage,
            previousMainTab = args.previousMainTab,
            identityInitOverlayVisible = args.identityInitOverlayVisible,
            runtime = args.runtime,
            onNavigateFallback = args.onNavigateFallback
        )
    )
}

@Composable
internal fun AssistantTrustedCalleeRuntimeShellEffect(args: AssistantTrustedCalleeRuntimeShellEffectArgs) {
    FinalTrustedCalleeRuntimeEffect(
        currentPage = args.currentPage,
        runtime = args.runtime
    )
}
