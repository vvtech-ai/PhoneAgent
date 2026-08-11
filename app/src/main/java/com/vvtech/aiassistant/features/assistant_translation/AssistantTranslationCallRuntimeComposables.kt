package com.vvtech.aiassistant.features.assistant_translation

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.features.assistant.AssistantTranslationCallRuntimeCallbacks
import com.vvtech.aiassistant.features.assistant.AssistantTranslationCallRuntimeController
import com.vvtech.aiassistant.features.assistant.AssistantTranslationCallRuntimeDeps
import com.vvtech.aiassistant.features.assistant.AssistantTranslationCallRuntimeState
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTranslationAudioControlEffect
import com.vvtech.aiassistant.features.assistant.FinalTranslationCallKeepScreenOnEffect
import com.vvtech.aiassistant.features.assistant.FinalTranslationCallTimerEffect
import com.vvtech.aiassistant.features.assistant.TranslationCallAudioSocketClient

@Composable
internal fun rememberAssistantTranslationCallRuntimeController(
    context: Context,
    deps: AssistantTranslationCallRuntimeDeps,
    callbacks: AssistantTranslationCallRuntimeCallbacks
): AssistantTranslationCallRuntimeController {
    val state = AssistantTranslationCallRuntimeState(
        audioClient = remember(context) { TranslationCallAudioSocketClient(context) },
        seconds = rememberSaveable { mutableStateOf(0) },
        muted = rememberSaveable { mutableStateOf(false) },
        speaker = rememberSaveable { mutableStateOf(true) },
        panelCollapsed = rememberSaveable { mutableStateOf(false) },
        callId = rememberSaveable { mutableStateOf("") },
        status = remember { mutableStateOf<TranslationCallStatusResponse?>(null) },
        error = rememberSaveable { mutableStateOf<String?>(null) },
        audioChannelStatus = rememberSaveable { mutableStateOf<String?>(null) },
        starting = rememberSaveable { mutableStateOf(false) },
        audioPermissionGrantedSignal = rememberSaveable { mutableStateOf(0L) },
        lifecycleAttemptId = rememberSaveable { mutableStateOf("") },
        lifecycleOrigin = rememberSaveable { mutableStateOf("EXISTING_FLOW") },
        lifecycleFinalized = rememberSaveable { mutableStateOf(false) }
    )
    val controller = remember(context, deps.repository, deps.scope) {
        AssistantTranslationCallRuntimeController(state, deps, callbacks)
    }
    controller.updateCallbacks(callbacks)
    return controller
}

@Composable
internal fun FinalTranslationCallRuntimeEffects(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    currentPage: FinalPage,
    runtime: AssistantTranslationCallRuntimeController
) {
    FinalTranslationAudioControlEffect(
        currentPage = currentPage,
        muted = runtime.muted,
        speakerEnabled = runtime.speaker,
        translationCallAudioClient = runtime.audioClient
    )
    FinalTranslationCallKeepScreenOnEffect(
        context = context,
        lifecycleOwner = lifecycleOwner,
        keepScreenOnForTranslationCall = runtime.shouldKeepScreenOn(currentPage)
    )
    FinalTranslationCallTimerEffect(
        currentPage = currentPage,
        callConnected = runtime.status?.callState.equals("CONNECTED", ignoreCase = true),
        onTick = runtime::tickConnectedSecond
    )
    LaunchedEffect(currentPage, runtime.callId) {
        runtime.pollWhileActive { currentPage }
    }
}
