package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.*
import kotlinx.coroutines.delay

@Composable
internal fun SingleFlowNativeContentShell(
    main: SingleFlowNativeMainContentState,
    input: SingleFlowNativeInputState,
    callOverlay: SingleFlowNativeCallOverlayState,
    receipt: SingleFlowNativeReceiptState,
    callbacks: SingleFlowNativeContentCallbacks
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
            .then(
                if (!main.realFlowEnabled) {
                    Modifier.pointerInput(Unit) {
                        detectTapGestures(onDoubleTap = { callbacks.onAdvanceMockStep() })
                    }
                } else {
                    Modifier
                }
            )
    ) {
        SingleFlowNativeContentColumn(main = main, input = input, callbacks = callbacks)
        SingleFlowNativeInputSection(main = main, input = input, callbacks = callbacks)
        SingleFlowNativeOverlaySection(
            main = main,
            callOverlay = callOverlay,
            receipt = receipt,
            callbacks = callbacks
        )
        LaunchedEffect(receipt.showHint) {
            if (receipt.showHint) {
                delay(6000)
                callbacks.onAutoDismissReceiptHint()
            }
        }
    }
}

@Composable
private fun BoxScope.SingleFlowNativeInputSection(
    main: SingleFlowNativeMainContentState,
    input: SingleFlowNativeInputState,
    callbacks: SingleFlowNativeContentCallbacks
) {
    if (main.pureVoiceMode) return
    if (main.realFlowEnabled) {
        SingleFlowRealInputBar(
            assistantState = main.assistantState,
            inputMode = main.inputMode,
            textInput = input.textInput,
            bottomOverlayInset = input.bottomOverlayInset,
            onInputModeChange = callbacks.onInputModeChange,
            onTextInputChange = callbacks.onTextInputChange,
            onSubmitText = callbacks.onSubmitText,
            onVoiceButtonTap = callbacks.onVoiceButtonTap,
            onPauseTtsPlayback = callbacks.onPauseTtsPlayback,
            onStopVoiceInteraction = callbacks.onStopVoiceInteraction,
            onComposerHeightChanged = callbacks.onComposerHeightChanged
        )
    } else {
        SingleFlowDemoInputPanel(
            inputMode = main.inputMode,
            textInput = input.textInput,
            listening = main.listening,
            bottomOverlayInset = input.bottomOverlayInset,
            onInputModeChange = callbacks.onInputModeChange,
            onTextInputChange = callbacks.onTextInputChange,
            onSubmitText = callbacks.onSubmitText,
            onVoiceButtonTap = callbacks.onVoiceButtonTap,
            onStopClick = callbacks.onStopClick,
            onComposerHeightChanged = callbacks.onComposerHeightChanged
        )
    }
}

@Composable
private fun BoxScope.SingleFlowNativeOverlaySection(
    main: SingleFlowNativeMainContentState,
    callOverlay: SingleFlowNativeCallOverlayState,
    receipt: SingleFlowNativeReceiptState,
    callbacks: SingleFlowNativeContentCallbacks
) {
    SingleFlowMockCallOverlay(
        callVisible = callOverlay.visible,
        callName = callOverlay.name,
        callSub = callOverlay.subTitle,
        callStatus = callOverlay.status,
        callSeconds = callOverlay.seconds,
        callTranscripts = callOverlay.transcripts,
        callListState = callOverlay.listState,
        callMuted = callOverlay.muted,
        callSpeaker = callOverlay.speaker,
        onToggleMuted = callbacks.onToggleMuted,
        onToggleSpeaker = callbacks.onToggleSpeaker,
        onEndCall = callbacks.onEndCall
    )

    if (receipt.showOverlay) {
        SfTaskReceiptOverlay(
            restaurantName = receipt.restaurantName,
            time = receipt.time,
            partySize = receipt.partySize,
            onDismiss = callbacks.onDismissReceipt
        )
    }

    SingleFlowReceiptHintOverlay(
        showReceiptHint = receipt.showHint,
        onDoNotShowAgain = callbacks.onDoNotShowReceiptAgain
    )

    if (main.pureVoiceMode && ShowVoiceDebugOverlay) {
        VoiceDebugOverlay(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 72.dp),
            threadItems = main.threadItems,
            clarificationSteps = main.assistantState?.clarificationSteps ?: emptyList(),
            liveUserTranscript = main.assistantState?.liveUserTranscript,
            liveAssistantTranscript = main.assistantState?.liveAssistantTranscript,
            status = main.assistantState?.status ?: ""
        )
    }
}

@Composable
private fun ColumnScope.SingleFlowNativeMainSection(
    main: SingleFlowNativeMainContentState,
    input: SingleFlowNativeInputState,
    callbacks: SingleFlowNativeContentCallbacks
) {
    SingleFlowHeader(stage = main.stage, closeTaskAction = main.closeTaskAction)

    if (main.pureVoiceMode) {
        SingleFlowPureVoiceContent(
            SingleFlowPureVoiceContentArgs(
                entryKey = main.entryKey,
                realFlowEnabled = main.realFlowEnabled,
                assistantState = main.assistantState,
                inputMode = main.inputMode,
                textInput = input.textInput,
                activeCallModelTitle = main.activeCallModelTitle,
                listening = main.listening,
                mockAiSpeaking = main.mockAiSpeaking,
                voiceLanguage = main.voiceLanguage,
                pureVoicePrecheck = main.pureVoicePrecheck,
                ocrBinding = main.pureVoiceOcrBinding,
                showMockRestaurantOptions = main.showMockRestaurantOptions,
                restaurants = main.restaurants,
                onInputModeChange = callbacks.onInputModeChange,
                onOpenCallModelSheet = callbacks.onOpenCallModelSheet,
                onTextInputChange = callbacks.onTextInputChange,
                onSubmitText = callbacks.onSubmitText,
                onVoiceButtonTap = callbacks.onPureVoiceButtonTap,
                onStop = callbacks.onPureVoiceStop,
                onCancel = callbacks.onPureVoiceCancel,
                onTooShort = callbacks.onPureVoiceTooShort,
                onSelectMockRestaurant = callbacks.onSelectMockRestaurant,
                onAgentOptionSelect = callbacks.onAgentOptionSelect
            )
        )
    } else {
        SingleFlowDialogueList(
            listState = main.listState,
            realFlowEnabled = main.realFlowEnabled,
            assistantState = main.assistantState,
            inputMode = main.inputMode,
            voiceLanguage = main.voiceLanguage,
            composerReserve = main.composerReserve,
            threadItems = main.threadItems,
            savedContacts = main.savedContacts,
            supplementContact = main.supplementContact,
            preferredSavedContact = main.preferredSavedContact,
            manualContactMode = main.manualContactMode,
            contactInputError = main.contactInputError,
            voiceContactPromptTaskId = main.voiceContactPromptTaskId,
            selectedDetailQuestionIds = main.selectedDetailQuestionIds,
            onRealSelectionOptionSelected = callbacks.onRealSelectionOptionSelected,
            onConfirmSavedContact = callbacks.onConfirmSavedContact,
            onManualContact = callbacks.onManualContact,
            onToggleQuestion = callbacks.onToggleQuestion,
            onConfirmDetails = callbacks.onConfirmDetails,
            onSkipDetails = callbacks.onSkipDetails,
            onConfirmSummary = callbacks.onConfirmSummary,
            onMockCtaClick = callbacks.onMockCtaClick
        )
    }
}

@Composable
private fun BoxScope.SingleFlowNativeContentColumn(
    main: SingleFlowNativeMainContentState,
    input: SingleFlowNativeInputState,
    callbacks: SingleFlowNativeContentCallbacks
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .padding(top = 14.dp)
    ) {
        SingleFlowNativeMainSection(main = main, input = input, callbacks = callbacks)
    }
}
