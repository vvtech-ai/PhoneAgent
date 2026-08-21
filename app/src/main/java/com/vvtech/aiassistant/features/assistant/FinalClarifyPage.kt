package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_tasks.AssistantClarifyFallbackBannerCard
import com.vvtech.aiassistant.features.assistant_tasks.AssistantClarifyOptionPickerCard

internal data class FinalClarifyPageState(
    val restaurantOptions: List<FinalOption>,
    val fallbackOptions: List<FinalOption>,
    val selectedRestaurantId: String?,
    val selectedFallbackIds: List<String>,
    val requiredFallbackIds: List<String>,
    val restaurantConfirmed: Boolean,
    val fallbackConfirmed: Boolean,
    val restaurantConfirming: Boolean,
    val fallbackConfirming: Boolean
)

internal data class FinalClarifyPageCallbacks(
    val onBack: () -> Unit,
    val onStop: () -> Unit,
    val onSelectRestaurant: (String) -> Unit,
    val onConfirmRestaurant: () -> Unit,
    val onToggleFallbackSelect: (String) -> Unit,
    val onToggleFallbackRequired: (String, Boolean) -> Unit,
    val onConfirmFallback: () -> Unit,
    val onNext: () -> Unit
)

internal data class FinalClarifyPageArgs(
    val state: FinalClarifyPageState,
    val callbacks: FinalClarifyPageCallbacks
)

@Composable
internal fun FinalClarifyPageV3(args: FinalClarifyPageArgs) {
    val state = args.state
    val callbacks = args.callbacks
    val restaurantOptions = state.restaurantOptions
    val fallbackOptions = state.fallbackOptions
    val selectedRestaurantId = state.selectedRestaurantId
    val selectedFallbackIds = state.selectedFallbackIds
    val requiredFallbackIds = state.requiredFallbackIds
    val restaurantConfirmed = state.restaurantConfirmed
    val fallbackConfirmed = state.fallbackConfirmed
    val restaurantConfirming = state.restaurantConfirming
    val fallbackConfirming = state.fallbackConfirming
    val selectedRestaurant = restaurantOptions.firstOrNull { it.id == selectedRestaurantId }
    val selectedFallbacks = fallbackOptions.filter { selectedFallbackIds.contains(it.id) }
    val choiceSectionVisible = restaurantConfirmed || fallbackConfirming || fallbackConfirmed || selectedFallbacks.isNotEmpty()
    val toConfirmEnabled =
        restaurantConfirmed && fallbackConfirmed && selectedFallbacks.isNotEmpty() && !restaurantConfirming && !fallbackConfirming
    val requiredText = stringResource(R.string.clarify_required)
    val optionalText = stringResource(R.string.clarify_mention_optional)
    val selectedFallbackSummary = selectedFallbacks.joinToString("；") { option ->
        val stateText = if (requiredFallbackIds.contains(option.id)) {
            requiredText
        } else {
            optionalText
        }
        "${option.userLabel}（$stateText）"
    }
    val promptText = when {
        fallbackConfirmed -> stringResource(R.string.clarify_done_prompt)
        fallbackConfirming -> stringResource(R.string.clarify_processing_fallback)
        restaurantConfirmed -> stringResource(R.string.clarify_fallback_prompt)
        restaurantConfirming -> stringResource(R.string.clarify_processing_restaurant)
        else -> stringResource(R.string.clarify_choose_restaurant_prompt)
    }

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(
            title = stringResource(R.string.clarify_title),
            onBack = callbacks.onBack,
            trailing = { FinalStopButton(onClick = callbacks.onStop) }
        )
        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 122.dp)
            ) {
                item {
                    FinalAssistantRoleBubbleV3(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp, bottom = 12.dp),
                        text = selectedRestaurant?.let {
                            stringResource(R.string.clarify_restaurant_confirmed, it.title)
                        } ?: stringResource(R.string.clarify_intro_prompt)
                    )
                }
                item {
                    FinalAssistantRoleBubbleV3(
                        modifier = Modifier.fillMaxWidth(),
                        text = promptText
                    )
                }
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = 4.dp, end = 4.dp, top = 16.dp, bottom = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.clarify_candidate_restaurants),
                            color = Color(0xFF111111),
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }
                itemsIndexed(restaurantOptions) { index, option ->
                    val tag = when (index) {
                        0 -> stringResource(R.string.clarify_tag_recommended)
                        1 -> stringResource(R.string.clarify_tag_alternative)
                        else -> stringResource(R.string.clarify_tag_popular)
                    }
                    AssistantClarifyOptionPickerCard(
                        title = option.title,
                        subtitle = option.subtitle,
                        tag = tag,
                        selected = option.id == selectedRestaurantId,
                        onClick = { callbacks.onSelectRestaurant(option.id) }
                    )
                }

                if (selectedRestaurant != null) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp)
                        ) {
                            FinalUserConfirmBubbleV3(
                                text = selectedRestaurant.userLabel,
                                showConfirm = !restaurantConfirmed && !restaurantConfirming,
                                onConfirm = callbacks.onConfirmRestaurant
                            )
                            AnimatedVisibility(
                                visible = restaurantConfirming,
                                enter = fadeIn(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase)),
                                exit = fadeOut(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase))
                            ) {
                                FinalAiLoadingBubbleV3(modifier = Modifier.padding(top = 10.dp))
                            }
                            AnimatedVisibility(
                                visible = restaurantConfirmed,
                                enter = fadeIn(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase)) + slideInVertically(
                                    animationSpec = tween(durationMillis = FinalMotionDurationMs, easing = FinalMotionEase),
                                    initialOffsetY = { it / 3 }
                                ),
                                exit = fadeOut(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase))
                            ) {
                                FinalAssistantRoleBubbleV3(
                                    modifier = Modifier.padding(top = 10.dp),
                                    text = stringResource(R.string.clarify_restaurant_followup)
                                )
                            }
                        }
                    }
                }

                if (choiceSectionVisible) {
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = 4.dp, end = 4.dp, top = 16.dp, bottom = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = stringResource(R.string.clarify_handling_options),
                                color = Color(0xFF111111),
                                fontSize = 17.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                        }
                    }
                    items(fallbackOptions) { option ->
                        val selected = selectedFallbackIds.contains(option.id)
                        val required = selected && requiredFallbackIds.contains(option.id)
                        AssistantClarifyFallbackBannerCard(
                            title = option.title,
                            subtitle = option.subtitle,
                            selected = selected,
                            required = required,
                            onToggleSelected = { callbacks.onToggleFallbackSelect(option.id) },
                            onToggleRequired = { requiredNow ->
                                callbacks.onToggleFallbackRequired(option.id, requiredNow)
                            }
                        )
                    }
                }

                if (selectedFallbacks.isNotEmpty() && choiceSectionVisible) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp)
                        ) {
                            FinalUserConfirmBubbleV3(
                                text = selectedFallbackSummary,
                                showConfirm = !fallbackConfirmed && !fallbackConfirming,
                                onConfirm = callbacks.onConfirmFallback
                            )
                            AnimatedVisibility(
                                visible = fallbackConfirming,
                                enter = fadeIn(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase)),
                                exit = fadeOut(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase))
                            ) {
                                FinalAiLoadingBubbleV3(modifier = Modifier.padding(top = 10.dp))
                            }
                            AnimatedVisibility(
                                visible = fallbackConfirmed,
                                enter = fadeIn(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase)) + slideInVertically(
                                    animationSpec = tween(durationMillis = FinalMotionDurationMs, easing = FinalMotionEase),
                                    initialOffsetY = { it / 3 }
                                ),
                                exit = fadeOut(tween(durationMillis = FinalThreadFadeDurationMs, easing = FinalFadeEase))
                            ) {
                                FinalAssistantRoleBubbleV3(
                                    modifier = Modifier.padding(top = 10.dp),
                                    text = stringResource(R.string.clarify_fallback_confirmed)
                                )
                            }
                        }
                    }
                }
            }
            FinalActionButton(
                label = stringResource(R.string.clarify_next_confirm),
                tone = FinalButtonTone.Success,
                enabled = toConfirmEnabled,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                onClick = callbacks.onNext
            )
        }
    }
}
