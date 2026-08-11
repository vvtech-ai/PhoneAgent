package com.vvtech.aiassistant.features.translation_call.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import kotlinx.coroutines.delay

internal const val TranslationCallPreflightMinimumVisibleMs = 900L

internal fun translationCallPreflightRemainingMs(
    startedAtMs: Long,
    nowMs: Long
): Long = (TranslationCallPreflightMinimumVisibleMs - (nowMs - startedAtMs))
    .coerceIn(0L, TranslationCallPreflightMinimumVisibleMs)

@Composable
internal fun rememberTranslationCallPreflightVisible(
    state: TranslationCallUiState
): Boolean {
    val initialElapsed = state.visible &&
        translationCallPreflightRemainingMs(
            startedAtMs = state.startedAtMs,
            nowMs = System.currentTimeMillis()
        ) == 0L
    var minimumDurationElapsed by remember(state.callId) {
        mutableStateOf(initialElapsed)
    }
    LaunchedEffect(state.callId, state.startedAtMs, state.visible) {
        if (!state.visible || state.startedAtMs <= 0L) {
            minimumDurationElapsed = true
            return@LaunchedEffect
        }
        minimumDurationElapsed = false
        val remaining = translationCallPreflightRemainingMs(
            startedAtMs = state.startedAtMs,
            nowMs = System.currentTimeMillis()
        )
        if (remaining > 0L) delay(remaining)
        minimumDurationElapsed = true
    }
    return state.visible &&
        !state.terminal &&
        (state.phase == TranslationCallPhase.Preflight || !minimumDurationElapsed)
}
