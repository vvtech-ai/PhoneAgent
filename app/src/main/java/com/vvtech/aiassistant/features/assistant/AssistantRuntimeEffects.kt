package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.delay

@Composable
internal fun FinalTranslationAudioControlEffect(
    currentPage: FinalPage,
    muted: Boolean,
    speakerEnabled: Boolean,
    translationCallAudioClient: TranslationCallAudioSocketClient
) {
    LaunchedEffect(muted, speakerEnabled, currentPage) {
        if (currentPage == FinalPage.TranslateCall) {
            translationCallAudioClient.setMicrophoneMuted(muted)
            translationCallAudioClient.setSpeakerphoneEnabled(speakerEnabled)
        }
    }
}

@Composable
internal fun FinalPageRuntimeCleanupEffect(
    currentPage: FinalPage,
    onHideCallsDialSheet: () -> Unit,
    onResetVoiceClonePageState: () -> Unit
) {
    LaunchedEffect(currentPage) {
        if (currentPage != FinalPage.Calls) {
            onHideCallsDialSheet()
        }
        if (currentPage != FinalPage.VoiceCloneSettings) {
            onResetVoiceClonePageState()
        }
    }
}

@Composable
internal fun FinalNormalCallTimerEffect(
    currentPage: FinalPage,
    onTick: () -> Unit
) {
    LaunchedEffect(currentPage) {
        if (currentPage == FinalPage.NormalCall) {
            while (true) {
                delay(1000L)
                onTick()
            }
        }
    }
}

@Composable
internal fun FinalTranslationCallTimerEffect(
    currentPage: FinalPage,
    callConnected: Boolean,
    onTick: () -> Unit
) {
    LaunchedEffect(currentPage, callConnected) {
        if (currentPage == FinalPage.TranslateCall) {
            while (true) {
                delay(1000L)
                if (callConnected) {
                    onTick()
                }
            }
        }
    }
}

@Composable
internal fun FinalAiCallTimerEffect(
    currentPage: FinalPage,
    showAiCallPage: Boolean,
    callConnected: Boolean,
    onReset: () -> Unit,
    onTick: () -> Unit
) {
    LaunchedEffect(currentPage == FinalPage.AiCall, showAiCallPage, callConnected) {
        if (currentPage == FinalPage.AiCall || showAiCallPage) {
            onReset()
            while (true) {
                delay(1000L)
                onTick()
            }
        }
    }
}
