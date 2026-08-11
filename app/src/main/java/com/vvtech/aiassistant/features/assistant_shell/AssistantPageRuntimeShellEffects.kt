package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.FinalAiCallTimerEffect
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalNormalCallTimerEffect
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalPageLifecycleLoggingEffects
import com.vvtech.aiassistant.features.assistant.FinalPageResourceEffects
import com.vvtech.aiassistant.features.assistant.FinalPageRuntimeCleanupEffect
import com.vvtech.aiassistant.features.assistant.FinalSingleFlowBackgroundEffect
import com.vvtech.aiassistant.features.assistant.TranslationCallAudioSocketClient

@Composable
internal fun AssistantPageLifecycleShellEffects(
    lifecycleOwner: LifecycleOwner,
    currentPage: FinalPage,
    currentMainTab: FinalMainTab,
    previousMainTab: FinalMainTab
) {
    FinalPageLifecycleLoggingEffects(
        lifecycleOwner = lifecycleOwner,
        currentPage = currentPage,
        currentMainTab = currentMainTab,
        previousMainTab = previousMainTab
    )
}

@Composable
internal fun AssistantPageResourceShellEffects(
    context: Context,
    currentPage: FinalPage,
    translationCallAudioClient: TranslationCallAudioSocketClient
) {
    FinalPageResourceEffects(
        context = context,
        currentPage = currentPage,
        translationCallAudioClient = translationCallAudioClient
    )
}

@Composable
internal fun AssistantSingleFlowBackgroundShellEffect(
    currentPage: FinalPage,
    lifecycleOwner: LifecycleOwner,
    assistantViewModel: AssistantViewModel
) {
    FinalSingleFlowBackgroundEffect(
        currentPage = currentPage,
        lifecycleOwner = lifecycleOwner,
        assistantViewModel = assistantViewModel
    )
}

internal data class AssistantPageRuntimeShellEffectsArgs(
    val currentPage: FinalPage,
    val showAiCallPage: Boolean,
    val callConnected: Boolean,
    val callbacks: AssistantPageRuntimeShellCallbacks
)

internal data class AssistantPageRuntimeShellCallbacks(
    val onHideCallsDialSheet: () -> Unit,
    val onResetVoiceClonePageState: () -> Unit,
    val onNormalCallTick: () -> Unit,
    val onAiCallReset: () -> Unit,
    val onAiCallTick: () -> Unit
)

@Composable
internal fun AssistantPageRuntimeShellEffects(args: AssistantPageRuntimeShellEffectsArgs) {
    FinalPageRuntimeCleanupEffect(
        currentPage = args.currentPage,
        onHideCallsDialSheet = args.callbacks.onHideCallsDialSheet,
        onResetVoiceClonePageState = args.callbacks.onResetVoiceClonePageState
    )
    FinalNormalCallTimerEffect(
        currentPage = args.currentPage,
        onTick = args.callbacks.onNormalCallTick
    )
    FinalAiCallTimerEffect(
        currentPage = args.currentPage,
        showAiCallPage = args.showAiCallPage,
        callConnected = args.callConnected,
        onReset = args.callbacks.onAiCallReset,
        onTick = args.callbacks.onAiCallTick
    )
}
