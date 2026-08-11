package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_calls.isAiCallConnected

internal data class AssistantRootPostActionShellEffectsArgs(
    val currentPage: FinalPage,
    val assistantUiState: Index9AssistantUiState,
    val taskEntry: AssistantTaskEntryState,
    val rootRuntimeGraph: AssistantRootRuntimeGraph,
    val rootActionGraph: AssistantRootActionGraph
)

@Composable
internal fun AssistantRootPostActionShellEffects(
    args: AssistantRootPostActionShellEffectsArgs
) {
    val taskEntry = args.taskEntry
    val state = args.rootRuntimeGraph.state
    val runtime = args.rootRuntimeGraph.runtime
    val voiceEntryRootActions = args.rootActionGraph.voiceEntry
    val callEntryActions = args.rootActionGraph.callEntry

    AssistantVoiceEntryPermissionSignalShellEffect(
        AssistantVoiceEntryPermissionSignalShellEffectArgs(
            voiceEntryPermissionGrantedSignal = taskEntry.voiceEntryPermissionGrantedSignal,
            hasValidPendingVoiceEntry = voiceEntryRootActions::hasValidPendingVoiceEntry,
            onContinueVoiceEntryAfterMicrophoneGranted =
                voiceEntryRootActions::continueVoiceEntryAfterMicrophoneGranted,
            onVoiceEntryPermissionGrantedSignalReset = {
                taskEntry.voiceEntryPermissionGrantedSignal = 0L
            }
        )
    )

    AssistantTranslationAudioPermissionSignalShellEffect(
        AssistantTranslationAudioPermissionSignalShellEffectArgs(
            translationCallAudioPermissionGrantedSignal =
                runtime.translation.audioPermissionGrantedSignal,
            onStartRealtimeTranslationCallFromDial =
                callEntryActions::runDialSheetAction
        )
    )

    AssistantTaskEntryFeedbackShellEffects(
        AssistantTaskEntryFeedbackShellEffectsArgs(
            aiThinking = AssistantAiThinkingFeedbackEffectArgs(
                aiThinking = taskEntry.aiThinking,
                onAiThinkingChange = { taskEntry.aiThinking = it },
                onAiReplyVisibleChange = { taskEntry.aiReplyVisible = it }
            ),
            restaurantConfirm = AssistantRestaurantConfirmFeedbackEffectArgs(
                confirmingRestaurantId = taskEntry.confirmingRestaurantId,
                selectedRestaurantId = taskEntry.selectedRestaurantId,
                onRestaurantConfirmedChange = { taskEntry.restaurantConfirmed = it },
                onConfirmingRestaurantIdChange = { taskEntry.confirmingRestaurantId = it }
            ),
            fallbackConfirm = AssistantFallbackConfirmFeedbackEffectArgs(
                confirmingFallbackId = taskEntry.confirmingFallbackId,
                selectedFallbackIds = taskEntry.selectedFallbackIds,
                restaurantConfirmed = taskEntry.restaurantConfirmed,
                onFallbackConfirmedChange = { taskEntry.fallbackConfirmed = it },
                onConfirmingFallbackIdChange = { taskEntry.confirmingFallbackId = it }
            )
        )
    )

    AssistantPageRuntimeShellEffects(
        AssistantPageRuntimeShellEffectsArgs(
            currentPage = args.currentPage,
            showAiCallPage = args.assistantUiState.showAiCallPage,
            callConnected = isAiCallConnected(args.assistantUiState.callPageData.callState),
            callbacks = AssistantPageRuntimeShellCallbacks(
                onHideCallsDialSheet = { state.callDial.hideDialSheet() },
                onResetVoiceClonePageState = runtime.voiceClone::resetPageStateOnLeave,
                onNormalCallTick = { state.callDial.normalCallSeconds += 1 },
                onAiCallReset = { taskEntry.aiCallSeconds = 0 },
                onAiCallTick = { taskEntry.aiCallSeconds += 1 }
            )
        )
    )
}
