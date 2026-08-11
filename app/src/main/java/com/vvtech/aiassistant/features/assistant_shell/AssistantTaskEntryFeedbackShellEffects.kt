package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalAiThinkingEffect
import com.vvtech.aiassistant.features.assistant.FinalAiThinkingEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalFallbackConfirmEffect
import com.vvtech.aiassistant.features.assistant.FinalFallbackConfirmEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalRestaurantConfirmEffect
import com.vvtech.aiassistant.features.assistant.FinalRestaurantConfirmEffectArgs

internal data class AssistantTaskEntryFeedbackShellEffectsArgs(
    val aiThinking: AssistantAiThinkingFeedbackEffectArgs,
    val restaurantConfirm: AssistantRestaurantConfirmFeedbackEffectArgs,
    val fallbackConfirm: AssistantFallbackConfirmFeedbackEffectArgs
)

internal data class AssistantAiThinkingFeedbackEffectArgs(
    val aiThinking: Boolean,
    val onAiThinkingChange: (Boolean) -> Unit,
    val onAiReplyVisibleChange: (Boolean) -> Unit
)

internal data class AssistantRestaurantConfirmFeedbackEffectArgs(
    val confirmingRestaurantId: String?,
    val selectedRestaurantId: String?,
    val onRestaurantConfirmedChange: (Boolean) -> Unit,
    val onConfirmingRestaurantIdChange: (String?) -> Unit
)

internal data class AssistantFallbackConfirmFeedbackEffectArgs(
    val confirmingFallbackId: String?,
    val selectedFallbackIds: List<String>,
    val restaurantConfirmed: Boolean,
    val onFallbackConfirmedChange: (Boolean) -> Unit,
    val onConfirmingFallbackIdChange: (String?) -> Unit
)

@Composable
internal fun AssistantTaskEntryFeedbackShellEffects(args: AssistantTaskEntryFeedbackShellEffectsArgs) {
    FinalAiThinkingEffect(
        FinalAiThinkingEffectArgs(
            aiThinking = args.aiThinking.aiThinking,
            onAiThinkingChange = args.aiThinking.onAiThinkingChange,
            onAiReplyVisibleChange = args.aiThinking.onAiReplyVisibleChange
        )
    )
    FinalRestaurantConfirmEffect(
        FinalRestaurantConfirmEffectArgs(
            confirmingRestaurantId = args.restaurantConfirm.confirmingRestaurantId,
            selectedRestaurantId = args.restaurantConfirm.selectedRestaurantId,
            onRestaurantConfirmedChange = args.restaurantConfirm.onRestaurantConfirmedChange,
            onConfirmingRestaurantIdChange = args.restaurantConfirm.onConfirmingRestaurantIdChange
        )
    )
    FinalFallbackConfirmEffect(
        FinalFallbackConfirmEffectArgs(
            confirmingFallbackId = args.fallbackConfirm.confirmingFallbackId,
            selectedFallbackIds = args.fallbackConfirm.selectedFallbackIds,
            restaurantConfirmed = args.fallbackConfirm.restaurantConfirmed,
            onFallbackConfirmedChange = args.fallbackConfirm.onFallbackConfirmedChange,
            onConfirmingFallbackIdChange = args.fallbackConfirm.onConfirmingFallbackIdChange
        )
    )
}
