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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    val selectedFallbackSummary = selectedFallbacks.joinToString("；") { option ->
        val stateText = if (requiredFallbackIds.contains(option.id)) "必须满足" else "提及但不必须"
        "${option.userLabel}（$stateText）"
    }
    val promptText = when {
        fallbackConfirmed -> "处理方式已确认。下一步我会整理成任务确认卡。"
        fallbackConfirming -> "正在整理你的处理方式，请稍等。"
        restaurantConfirmed -> "如果没有包间或 19:00 没位，请确认这次的处理方式。"
        restaurantConfirming -> "正在整理你确认的餐厅信息，请稍等。"
        else -> "请先确认本次要联系哪一家餐厅。"
    }

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(
            title = "需求确认",
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
                        text = selectedRestaurant?.let { "已确认餐厅：${it.title}" }
                            ?: "你想订一个餐厅。我先帮你确认具体对象，再确认没有包间时要如何处理。"
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
                            text = "候选餐厅",
                            color = Color(0xFF111111),
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }
                itemsIndexed(restaurantOptions) { index, option ->
                    val tag = when (index) {
                        0 -> "推荐"
                        1 -> "备选"
                        else -> "热门"
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
                                    text = "好的。如果这家门店没有包间，或 19:00 没位，我需要提前知道你的处理方式，避免在通话中来回打断你。"
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
                                text = "处理方式",
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
                                    text = "明白了。我会把是否有低消、以及如果安排包间是否有包间费作为备注问询项一并带回。下一步我会整理成确认卡，请你在拨打前再确认一次。"
                                )
                            }
                        }
                    }
                }
            }
            FinalActionButton(
                label = "继续到任务确认",
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
