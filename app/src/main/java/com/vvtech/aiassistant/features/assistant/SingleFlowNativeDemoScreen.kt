package com.vvtech.aiassistant.features.assistant

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant_singleflow.SfPending
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeCallOverlayState
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeContentCallbacks
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeContentShell
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeDemoScreenArgs
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeEntryEffectCallbacks
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeEntryEffects
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeEntryEffectsArgs
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeInputState
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeMainContentState
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeMockFlowController
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeReceiptState
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeRuntimeEffectCallbacks
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeRuntimeEffects
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeRuntimeEffectsArgs
import com.vvtech.aiassistant.features.assistant_singleflow.rememberSingleFlowNativeStateHolder
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.rememberPureVoiceOcrBinding
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal enum class SfInputMode {
    Text,
    Voice
}

@Composable
internal fun SingleFlowNativeDemoScreen(args: SingleFlowNativeDemoScreenArgs = SingleFlowNativeDemoScreenArgs()) {
    val onBack = args.onBack
    val onStop = args.onStop
    val initialCommand = args.initialCommand
    val startInVoice = args.startInVoice
    val resumeListeningOnly = args.resumeListeningOnly
    val entryKey = args.entryKey
    val onSubmitTask = args.onSubmitTask
    val assistantState = args.assistantState
    val onSelectSelectionOption = args.onSelectSelectionOption
    val onConfirmTask = args.onConfirmTask
    val onSubmitSceneSupplement = args.onSubmitSceneSupplement
    val onStartVoiceInteraction = args.onStartVoiceInteraction
    val onStartNewVoiceTaskEntry = args.onStartNewVoiceTaskEntry
    val onToggleVoiceInput = args.onToggleVoiceInput
    val onPauseTtsPlayback = args.onPauseTtsPlayback
    val onSpeakVoicePrompt = args.onSpeakVoicePrompt
    val onBeginVoiceContactReentry = args.onBeginVoiceContactReentry
    val onBeginVoiceDefaultContactConfirmation = args.onBeginVoiceDefaultContactConfirmation
    val onBeginVoiceDetailSupplementPrompt = args.onBeginVoiceDetailSupplementPrompt
    val onBeginVoiceSummaryConfirmation = args.onBeginVoiceSummaryConfirmation
    val onVoiceContactCaptured = args.onVoiceContactCaptured
    val savedContacts = args.savedContacts
    val onCompleteDetailSupplement = args.onCompleteDetailSupplement
    val bottomOverlayInset = args.bottomOverlayInset
    val pureVoiceMode = args.pureVoiceMode
    val pureVoicePrecheck = args.pureVoicePrecheck
    val voiceLanguage = args.voiceLanguage
    val activeCallModelTitle = args.activeCallModelTitle
    val onOpenCallModelSheet = args.onOpenCallModelSheet
    val onStopVoiceInteraction = args.onStopVoiceInteraction
    val onManualPressVoiceInteraction = args.onManualPressVoiceInteraction
    val onManualCancelVoiceInteraction = args.onManualCancelVoiceInteraction
    val onManualTooShortVoiceInteraction = args.onManualTooShortVoiceInteraction
    val scope = rememberCoroutineScope()
    val realFlowEnabled = assistantState != null
    val sfContext = LocalContext.current
    val pureVoiceOcrBinding = rememberPureVoiceOcrBinding(
        sfContext, scope, entryKey, pureVoiceMode, assistantState, args.pureVoiceOcrHostCallbacks
    )
    val sfPrefs = remember(sfContext) {
        sfContext.getSharedPreferences("index9_native_screen", Context.MODE_PRIVATE)
    }
    val singleFlowState = rememberSingleFlowNativeStateHolder(
        receiptHintDismissedInitial = sfPrefs.getBoolean("hide_receipt_hint", false)
    )
    val mockFlowController = remember(singleFlowState, scope, pureVoiceMode) {
        SingleFlowNativeMockFlowController(
            state = singleFlowState,
            scope = scope,
            pureVoiceMode = pureVoiceMode
        )
    }

    with(singleFlowState) {
        val preferredSavedContact = savedContacts.firstOrNull { it.isDefault } ?: savedContacts.firstOrNull()

    BackHandler(enabled = onBack != null || callVisible) {
        if (callVisible) {
            callVisible = false
        } else {
            onBack?.invoke()
        }
    }

    fun submitDetailSupplement(detailText: String) {
        val contact = supplementContact ?: return
        onCompleteDetailSupplement?.invoke(contact, detailText)
    }

    suspend fun handleUserInput(raw: String) {
        val input = raw.trim()
        if (input.isBlank()) return
        addUserText(input)
        if (realFlowEnabled) {
            val supplement = assistantState?.detailSupplement
            if (supplement != null && onCompleteDetailSupplement != null) {
                val contact = supplementContact
                if (contact == null) {
                    val parsed = sfParseContactInput(input)
                    if (parsed == null) {
                        manualContactMode = true
                        contactInputError = "请按“姓名，188****0000”的格式输入姓名和手机号"
                    } else {
                        supplementContact = parsed
                        manualContactMode = false
                        contactInputError = null
                        selectedDetailQuestionIds.clear()
                    }
                } else {
                    contactInputError = null
                    onCompleteDetailSupplement.invoke(contact, input)
                }
            } else if (supplement != null && onSubmitSceneSupplement != null) {
                onSubmitSceneSupplement.invoke(input)
            } else {
                onSubmitTask?.invoke(input)
            }
            return
        }
        val normalized = input.lowercase()

        if (Regex("打开通话界面|进入通话界面|查看通话界面|通话中界面").containsMatchIn(normalized)) {
            openCallUi(slotRestaurant.ifBlank { restaurants.first().name })
            aiReply(currentAppText(
                "已为你打开 AI 通话界面。你可以查看状态、转写，并可手动关闭。",
                "The AI call screen is open. You can view status and transcripts, or close it manually."
            ))
            return
        }
        if (Regex("关闭通话界面|退出通话界面|返回对话").containsMatchIn(normalized)) {
            closeCallUi()
            aiReply(currentAppText(
                "已关闭通话界面，回到当前对话流。",
                "The call screen is closed. You are back in the current conversation."
            ))
            return
        }

        when (pending) {
            SfPending.Task -> {
                val (timeParsed, partyParsed) = sfExtractTimeAndParty(input, slotTime, slotParty)
                slotTime = timeParsed
                slotParty = partyParsed
                stage = 2
                aiReply(currentAppText(
                    "收到。我先给你三个候选门店。可以回复餐厅名称或第几个。",
                    "Got it. I found three candidate locations. Reply with the restaurant name or number."
                ))
                addOptions(restaurants)
                pending = SfPending.Restaurant
            }

            SfPending.Restaurant -> {
                val selected = sfParseRestaurantDecision(normalized, restaurants)
                if (selected == null) {
                    aiReply(currentAppText(
                        "我还没识别出你选了哪个门店，请回复“第一个/第二个/第三个”或直接说店名。",
                        "I did not catch which location you chose. Reply with first, second, third, or the restaurant name."
                    ))
                    return
                }
                slotRestaurant = selected.name
                aiReply(currentAppText(
                    "好的，已选 ${selected.name}。如果没有包间，我可以改订大厅吗？请直接回复“可以”或“不可以”。",
                    "Okay, ${selected.name} selected. If no private room is available, may I book the main dining area instead? Reply yes or no."
                ))
                pending = SfPending.Fallback
            }

            SfPending.Fallback -> {
                val fallback = sfParseFallback(normalized)
                if (fallback.isBlank()) {
                    aiReply(currentAppText(
                        "请直接回复“可以”或“不可以”，我再继续。",
                        "Please reply yes or no, then I will continue."
                    ))
                    return
                }
                slotFallback = fallback
                addSummary(currentAppText(
                    "我将联系 $slotRestaurant，预订 $slotTime $slotParty，优先包间；处理方式：$slotFallback；留您的联系方式，尾号9999。",
                    "I will contact $slotRestaurant to book $slotTime for $slotParty, prioritize a private room, handle fallback as $slotFallback, and leave your phone number ending in 9999."
                ))
                addCta(currentAppText("点击或回复“就这样”确认执行", "Tap or reply \"confirm\" to start"))
                pending = SfPending.ConfirmCall
            }

            SfPending.ConfirmCall -> {
                if (Regex("就这样|开始|确认|执行|去打").containsMatchIn(normalized)) {
                    mockFlowController.runCallFlow()
                } else {
                    aiReply(currentAppText(
                        "你可以点击绿色气泡，或回复“就这样”开始执行。",
                        "Tap the green bubble or reply \"confirm\" to start."
                    ))
                }
            }

            SfPending.Done -> {
                if (Regex("继续跟进|再来|新任务").containsMatchIn(normalized)) {
                    stage = 1
                    pending = SfPending.Task
                    slotRestaurant = ""
                    slotFallback = ""
                    aiReply(currentAppText(
                        "好的，开始下一轮。请直接告诉我新的任务需求。",
                        "Okay, starting a new round. Tell me the next task."
                    ))
                } else {
                    aiReply(currentAppText(
                        "任务已完成。若要新任务，请回复“新任务”或“继续跟进”。",
                        "Task completed. To start another task, reply \"new task\" or \"follow up\"."
                    ))
                }
            }
        }
    }

    fun submitTextInput() {
        val value = textInput.trim()
        if (value.isBlank()) return
        textInput = ""
        scope.launch { handleUserInput(value) }
    }

    fun stopAndReset() {
        resetLocalDemoFlow()
        scope.launch {
            aiReply(currentAppText(
                "流程已终止。请直接告诉我你的新任务需求。",
                "The flow has stopped. Tell me your new task."
            ))
        }
    }

    fun triggerStopAction() {
        when {
            onStop != null -> onStop()
            onBack != null -> onBack()
            else -> stopAndReset()
        }
    }

    fun onVoiceButtonTap() {
        if (realFlowEnabled) {
            inputMode = SfInputMode.Voice
            if (pureVoiceMode) {
                onToggleVoiceInput?.invoke() ?: onStartVoiceInteraction?.invoke()
            } else {
                onStartVoiceInteraction?.invoke()
            }
            return
        }
        if (listening) {
            listening = false
            return
        }
        inputMode = SfInputMode.Voice
        mockAiSpeaking = false
        listening = true
        scope.launch {
            val mockText = when (pending) {
                SfPending.Task -> "预订北海渔村，今晚8点半，五个人"
                SfPending.Restaurant -> "第一个"
                SfPending.Fallback -> "可以"
                SfPending.ConfirmCall -> "就这样"
                SfPending.Done -> "新任务"
            }
            delay(1500)
            listening = false
            handleUserInput(mockText)
        }
    }

    // Auto-call after 5 seconds at step 3
    LaunchedEffect(mockStep) {
        if (mockStep == 3 && !realFlowEnabled) {
            delay(5000)
            if (mockStep == 3) {
                mockFlowController.advanceMockStep()
            }
        }
    }

    // Simulate user speaking waveform when listening in mock mode
    LaunchedEffect(listening, realFlowEnabled) {
        if (listening && !realFlowEnabled) {
            delay(400)
            mockUserSpeaking = true
        } else {
            mockUserSpeaking = false
        }
    }

    SingleFlowNativeEntryEffects(
        args = SingleFlowNativeEntryEffectsArgs(
            state = singleFlowState,
            initialCommand = initialCommand,
            startInVoice = startInVoice,
            resumeListeningOnly = resumeListeningOnly,
            entryKey = entryKey,
            assistantState = assistantState,
            pureVoiceMode = pureVoiceMode,
            pureVoicePrecheck = pureVoicePrecheck,
            voiceLanguage = voiceLanguage
        ),
        callbacks = SingleFlowNativeEntryEffectCallbacks(
            onHandleUserInput = { input -> handleUserInput(input) },
            onStartVoiceInteraction = onStartVoiceInteraction,
            onStartNewVoiceTaskEntry = onStartNewVoiceTaskEntry,
            onSpeakVoicePrompt = onSpeakVoicePrompt
        )
    )

    SingleFlowNativeRuntimeEffects(
        args = SingleFlowNativeRuntimeEffectsArgs(
            state = singleFlowState,
            assistantState = assistantState,
            savedContacts = savedContacts
        ),
        callbacks = SingleFlowNativeRuntimeEffectCallbacks(
            onBack = onBack,
            onCompleteDetailSupplement = onCompleteDetailSupplement,
            onBeginVoiceContactReentry = onBeginVoiceContactReentry,
            onBeginVoiceDefaultContactConfirmation = onBeginVoiceDefaultContactConfirmation,
            onBeginVoiceDetailSupplementPrompt = onBeginVoiceDetailSupplementPrompt,
            onBeginVoiceSummaryConfirmation = onBeginVoiceSummaryConfirmation,
            onSpeakVoicePrompt = onSpeakVoicePrompt,
            onVoiceContactCaptured = onVoiceContactCaptured
        )
    )

    val density = LocalDensity.current
    val composerReserve = with(density) { composerHeightPx.toDp() } + 16.dp

    SingleFlowNativeContentShell(
        main = SingleFlowNativeMainContentState(
            stage = stage,
            entryKey = entryKey,
            pureVoiceMode = pureVoiceMode,
            realFlowEnabled = realFlowEnabled,
            assistantState = assistantState,
            inputMode = inputMode,
            voiceLanguage = voiceLanguage,
            activeCallModelTitle = activeCallModelTitle,
            pureVoicePrecheck = pureVoicePrecheck,
            pureVoiceOcrBinding = pureVoiceOcrBinding,
            listening = listening,
            mockAiSpeaking = mockAiSpeaking,
            showMockRestaurantOptions = !realFlowEnabled && pending == SfPending.Restaurant,
            restaurants = restaurants,
            listState = listState,
            composerReserve = composerReserve,
            threadItems = threadItems,
            savedContacts = savedContacts,
            supplementContact = supplementContact,
            preferredSavedContact = preferredSavedContact,
            manualContactMode = manualContactMode,
            contactInputError = contactInputError,
            voiceContactPromptTaskId = voiceContactPromptTaskId,
            selectedDetailQuestionIds = selectedDetailQuestionIds.toList(),
            closeTaskAction = onStop ?: onBack
        ),
        input = SingleFlowNativeInputState(textInput = textInput, bottomOverlayInset = bottomOverlayInset),
        callOverlay = SingleFlowNativeCallOverlayState(
            visible = callVisible,
            name = callName,
            subTitle = callSub,
            status = callStatus,
            seconds = callSeconds,
            transcripts = callTranscripts,
            listState = callListState,
            muted = callMuted,
            speaker = callSpeaker
        ),
        receipt = SingleFlowNativeReceiptState(
            showOverlay = showReceiptOverlay,
            restaurantName = slotRestaurant.ifBlank { restaurants.first().name },
            time = slotTime,
            partySize = slotParty,
            showHint = showReceiptHint
        ),
        callbacks = SingleFlowNativeContentCallbacks(
            onAdvanceMockStep = { mockFlowController.advanceMockStep() },
            onPureVoiceSelectionOption = { option ->
                addUserText(option.title)
                onSelectSelectionOption?.invoke(option)
            },
            onConfirmTask = onConfirmTask,
            onPureVoiceButtonTap = {
                if (realFlowEnabled) {
                    onManualPressVoiceInteraction?.invoke() ?: onVoiceButtonTap()
                } else {
                    onVoiceButtonTap()
                }
            },
            onPureVoiceStop = {
                if (realFlowEnabled) {
                    val voiceRecording = assistantState?.let { state ->
                        resolvePureVoiceListeningState(
                            manuallyPaused = state.voiceManuallyPaused,
                            voiceConnecting = state.voiceConnecting,
                            listening = state.listening,
                            apiAsrListening = state.apiAsrListening
                        )
                    } == true
                    if (voiceRecording) {
                        onStopVoiceInteraction?.invoke()
                    } else {
                        onPauseTtsPlayback?.invoke() ?: onStopVoiceInteraction?.invoke()
                    }
                } else {
                    listening = false
                }
            },
            onPureVoiceCancel = {
                if (realFlowEnabled) {
                    onManualCancelVoiceInteraction?.invoke()
                } else {
                    listening = false
                }
            },
            onPureVoiceTooShort = {
                if (realFlowEnabled) {
                    onManualTooShortVoiceInteraction?.invoke()
                } else {
                    listening = false
                }
            },
            onSelectMockRestaurant = { option ->
                scope.launch { handleUserInput(option.name) }
            },
            onAgentOptionSelect = { index ->
                onPauseTtsPlayback?.invoke()
                scope.launch {
                    handleUserInput(currentAppText("第${index + 1}个", "Option ${index + 1}"))
                }
            },
            onRealSelectionOptionSelected = { option ->
                addUserText(option.title)
                onSelectSelectionOption?.invoke(option)
            },
            onConfirmSavedContact = { entry ->
                confirmSupplementContact(entry.toEffectiveTaskContact())
            },
            onManualContact = {
                manualContactMode = true
                contactInputError = null
                if (inputMode == SfInputMode.Voice && realFlowEnabled) {
                    onBeginVoiceContactReentry?.invoke("请问你的称呼和手机号码")
                }
            },
            onToggleQuestion = { question ->
                toggleDetailQuestion(question.questionId)
            },
            onConfirmDetails = { supplement, selectedQuestionIds ->
                submitDetailSupplement(
                    sfBuildDetailSummary(
                        supplement = supplement,
                        selectedQuestionIds = selectedQuestionIds
                    )
                )
            },
            onSkipDetails = {
                selectedDetailQuestionIds.clear()
                submitDetailSupplement("")
            },
            onConfirmSummary = {
                assistantState?.confirmLabel?.let { addUserText(it) }
                onConfirmTask?.invoke()
            },
            onMockCtaClick = {
                if (pending == SfPending.ConfirmCall && !callRunning) {
                    scope.launch { mockFlowController.runCallFlow() }
                }
            },
            onTextInputChange = { textInput = it },
            onSubmitText = { submitTextInput() },
            onVoiceButtonTap = { onVoiceButtonTap() },
            onPauseTtsPlayback = onPauseTtsPlayback,
            onStopVoiceInteraction = onStopVoiceInteraction,
            onInputModeChange = { inputMode = it },
            onOpenCallModelSheet = { onOpenCallModelSheet?.invoke() },
            onStopClick = { triggerStopAction() },
            onComposerHeightChanged = { composerHeightPx = it },
            onToggleMuted = { callMuted = !callMuted },
            onToggleSpeaker = { callSpeaker = !callSpeaker },
            onEndCall = {
                callStatus = currentAppText("已结束", "Ended")
                addCallTranscript(currentAppText("用户手动结束了本次通话。", "User ended this call manually."))
                closeCallUi()
                if (callRunning) {
                    callRunning = false
                    pending = SfPending.Done
                }
            },
            onDismissReceipt = {
                showReceiptOverlay = false
                if (!receiptHintDismissed) {
                    showReceiptHint = true
                }
            },
            onDoNotShowReceiptAgain = {
                receiptHintDismissed = true
                sfPrefs.edit().putBoolean("hide_receipt_hint", true).apply()
                showReceiptHint = false
            },
            onAutoDismissReceiptHint = { showReceiptHint = false }
        )
    )
    }
}
