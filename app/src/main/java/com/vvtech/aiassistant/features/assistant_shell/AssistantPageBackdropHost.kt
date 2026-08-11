package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant.AssistantOverlayHostArgs
import com.vvtech.aiassistant.features.assistant.FinalFadeDurationMs
import com.vvtech.aiassistant.features.assistant.FinalFadeEase
import com.vvtech.aiassistant.features.assistant_ui.assistantBottomNavigationBackdrop

@Composable
internal fun AssistantPageBackdropHost(
    overlayArgs: AssistantOverlayHostArgs,
    content: @Composable () -> Unit
) {
    val hidden = overlayArgs.isBottomNavigationHidden()
    val progress by animateFloatAsState(
        targetValue = if (hidden) 0f else 1f,
        animationSpec = tween(
            durationMillis = FinalFadeDurationMs,
            easing = FinalFadeEase
        )
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .assistantBottomNavigationBackdrop(progress)
    ) {
        content()
    }
}

private fun AssistantOverlayHostArgs.isBottomNavigationHidden(): Boolean =
    !showBottomTabs ||
        assistantNavHidden ||
        showCallsDialSheet ||
        clientCallState.visible ||
        translationCallState.visible
