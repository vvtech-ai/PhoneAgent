package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.core.model.TranslationCallHangupRequest
import com.vvtech.aiassistant.core.model.TranslationCallStatusRequest
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.features.assistant_translation.TranslationRuntimeAudioEvent
import com.vvtech.aiassistant.features.assistant_translation.TranslationCallPolledStatusPolicy
import com.vvtech.aiassistant.features.assistant_translation.TranslationRuntimeEventPolicy
import com.vvtech.aiassistant.features.assistant_translation.TranslationRuntimeEventRecorder
import com.vvtech.aiassistant.features.assistant_calls.normalizeDialTarget
import com.vvtech.aiassistant.features.assistant_calls.TranslationCallOrigin
import com.vvtech.aiassistant.features.assistant_calls.TranslationCallLifecycleState
import com.vvtech.aiassistant.features.assistant_calls.TranslationCallLifecycleSnapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

internal class AssistantTranslationCallRuntimeController(
    private val state: AssistantTranslationCallRuntimeState,
    private val deps: AssistantTranslationCallRuntimeDeps,
    callbacks: AssistantTranslationCallRuntimeCallbacks
) {
    private val callLifecycle = TranslationCallLifecycleState(
        initial = TranslationCallLifecycleSnapshot(
            activeAttemptId = state.lifecycleAttemptId.value,
            origin = runCatching {
                TranslationCallOrigin.valueOf(state.lifecycleOrigin.value)
            }.getOrDefault(TranslationCallOrigin.EXISTING_FLOW),
            finalizedSinceBegin = state.lifecycleFinalized.value
        ),
        onSnapshotChange = { snapshot ->
            state.lifecycleAttemptId.value = snapshot.activeAttemptId
            state.lifecycleOrigin.value = snapshot.origin.name
            state.lifecycleFinalized.value = snapshot.finalizedSinceBegin
        }
    )
    private var callbacks: AssistantTranslationCallRuntimeCallbacks = callbacks
    private val translationRuntimeRecorder = TranslationRuntimeEventRecorder()

    var seconds by state.seconds
    var muted by state.muted
    var speaker by state.speaker
    var panelCollapsed by state.panelCollapsed
    var callId by state.callId
    var status by state.status
    var error by state.error
    var audioChannelStatus by state.audioChannelStatus
    var starting by state.starting
    var audioPermissionGrantedSignal by state.audioPermissionGrantedSignal

    val audioClient: TranslationCallAudioSocketClient = state.audioClient

    fun updateCallbacks(callbacks: AssistantTranslationCallRuntimeCallbacks) {
        this.callbacks = callbacks
    }

    fun onAudioPermissionGranted() {
        audioPermissionGrantedSignal += 1L
    }

    fun startFromDial(
        blockIfOffline: () -> Boolean,
        hasMicrophonePermission: () -> Boolean,
        requestMicrophonePermission: () -> Unit
    ) {
        if (blockIfOffline()) return
        if (!hasMicrophonePermission()) {
            requestMicrophonePermission()
            return
        }

        val normalized = normalizeDialTarget(callbacks.dialTarget())
        val target = when {
            normalized.isNotBlank() -> normalized
            normalizeDialTarget(callbacks.dialInput()).isNotBlank() ->
                normalizeDialTarget(callbacks.dialInput())
            callbacks.lastDialedNumber().isNotBlank() -> callbacks.lastDialedNumber()
            else -> ""
        }
        if (target.isBlank()) return

        val attemptId = callLifecycle.begin(TranslationCallOrigin.DIALER)
        callbacks.onLastDialedNumberChange(target)
        seconds = 0
        muted = false
        speaker = true
        panelCollapsed = false
        callbacks.onShowCallsDialSheetChange(false)
        starting = true
        error = null
        translationRuntimeRecorder.reset()

        val translationProvider = callbacks.translationProvider() ?: "QWEN_OMNI_PLUS"
        val providerDisplayName = translationProviderDisplayName(translationProvider)
        val usingQwenTranslation = isQwenTranslationProvider(translationProvider)
        val preferredTranslationVoice = if (usingQwenTranslation) {
            sanitizeTranslationQwenVoice(callbacks.translationQwenVoicePreference())
        } else {
            null
        }
        audioChannelStatus = "正在建立${providerDisplayName}实时翻译通话..."
        val pendingStatus = buildPendingTranslationStatus(
            provider = translationProvider,
            statusMessage = "正在发起${providerDisplayName}实时翻译通话...",
            voiceCapability = if (usingQwenTranslation) "BUILT_IN_VOICE_ONLY" else "SOURCE_VOICE_MIMIC_ONLY"
        )
        status = pendingStatus
        recordTranslationStatus(
            previous = null,
            current = pendingStatus,
            eventTypeOverride = "translation_call_start_requested"
        )
        callbacks.onNavigateToTranslateCall()

        val requestUserId = resolvedUserId()
        val request = buildTranslationStartRequest(
            userId = requestUserId,
            phoneNumber = target,
            displayName = null,
            translationProvider = translationProvider,
            qwenVoicePreference = preferredTranslationVoice,
            languageSettings = callbacks.translationQwenLanguageSettings()
        )

        deps.scope.launch {
            runCatching {
                deps.repository.startTranslationCall(request)
            }.onSuccess { response ->
                if (!callLifecycle.isActive(attemptId)) {
                    if (response.callId.isNotBlank()) {
                        runCatching {
                            deps.repository.hangUpTranslationCall(
                                TranslationCallHangupRequest(
                                    userId = requestUserId,
                                    callId = response.callId
                                )
                            )
                        }
                    }
                    return@onSuccess
                }
                starting = false
                callId = response.callId
                val previousStatus = status
                val nextStatus = response.toStatusResponse()
                status = nextStatus
                recordTranslationStatus(previousStatus, nextStatus)
                error = if (response.callState.equals("FAILED", ignoreCase = true)) {
                    response.statusMessage.ifBlank { "发起实时翻译通话失败" }
                } else {
                    null
                }
                error = localizeTranslationCallStatusText(error)
                if (response.callState.equals("FAILED", ignoreCase = true) ||
                    response.callId.isBlank()
                ) {
                    val failedStatus = if (response.callId.isBlank() &&
                        !response.callState.equals("FAILED", ignoreCase = true)
                    ) {
                        nextStatus.copy(
                            callState = "FAILED",
                            translationState = "FAILED",
                            statusMessage = "发起实时翻译通话失败：未返回通话标识"
                        )
                    } else {
                        nextStatus
                    }
                    status = failedStatus
                    error = localizeTranslationCallStatusText(failedStatus.statusMessage)
                    exitPage(failedStatus, recordResult = true, attemptId = attemptId)
                } else if (response.callId.isNotBlank()) {
                    audioClient.start(response.callId) { event ->
                        deps.scope.launch {
                            applyAudioSocketEvent(event)
                        }
                    }
                }
            }.onFailure { throwable ->
                if (!callLifecycle.isActive(attemptId)) {
                    return@onFailure
                }
                starting = false
                error = throwable.message ?: "发起实时翻译通话失败"
                error = localizeTranslationCallStatusText(error)
                val previousStatus = status
                val failedStatus = buildPendingTranslationStatus(
                    provider = translationProvider,
                    callState = "FAILED",
                    translationState = "FAILED",
                    statusMessage = error ?: "发起实时翻译通话失败"
                )
                status = failedStatus
                recordTranslationStatus(
                    previous = previousStatus,
                    current = failedStatus,
                    eventTypeOverride = "translation_call_start_failed",
                    reasonOverride = TranslationRuntimeEventPolicy.ProviderErrorReason,
                    throwable = throwable
                )
                exitPage(failedStatus, recordResult = true, attemptId = attemptId)
            }
        }
    }

    fun clearRuntimeState(stopAudioSocket: Boolean = true) {
        if (stopAudioSocket) {
            audioClient.stop("clear_translation_state")
        }
        callId = ""
        status = null
        error = null
        audioChannelStatus = null
        starting = false
        callLifecycle.clear()
    }

    fun resetForAccountBoundary(reason: String) {
        recordLifecycleCancelledRuntimeEvent(reason)
        audioClient.stop("account_boundary_$reason")
        clearRuntimeState(stopAudioSocket = false)
        seconds = 0
        muted = false
        speaker = true
        panelCollapsed = false
    }

    fun backOut() {
        val requestCallId = callId
        val requestAttemptId = callLifecycle.currentAttemptId()
        val userId = resolvedUserId()
        recordUserHangupRuntimeEvent()
        deps.scope.launch {
            val finalStatus = if (requestCallId.isNotBlank()) {
                runCatching {
                    deps.repository.hangUpTranslationCall(
                        TranslationCallHangupRequest(
                            userId = userId,
                            callId = requestCallId
                        )
                    )
                }.getOrNull()
            } else {
                status
            }
            if (!callLifecycle.isActive(requestAttemptId)) return@launch
            exitPage(finalStatus, recordResult = true, attemptId = requestAttemptId)
        }
    }

    fun hangupAndExit() {
        val requestCallId = callId
        val requestAttemptId = callLifecycle.currentAttemptId()
        val userId = resolvedUserId()
        recordUserHangupRuntimeEvent()
        deps.scope.launch {
            val hangupResult = if (requestCallId.isNotBlank()) {
                runCatching {
                    deps.repository.hangUpTranslationCall(
                        TranslationCallHangupRequest(
                            userId = userId,
                            callId = requestCallId
                        )
                    )
                }
            } else {
                Result.success(status)
            }
            if (!callLifecycle.isActive(requestAttemptId)) return@launch
            val finalStatus = hangupResult.getOrElse { throwable ->
                error = throwable.message ?: "结束实时翻译通话失败"
                status
            }
            finalStatus?.let { snapshot ->
                recordTranslationStatus(
                    previous = status,
                    current = snapshot,
                    eventTypeOverride = "translation_call_user_hangup_completed",
                    reasonOverride = TranslationRuntimeEventPolicy.UserEndedReason
                )
            }
            exitPage(finalStatus, recordResult = true, attemptId = requestAttemptId)
        }
    }

    fun exitPage(
        finalStatus: TranslationCallStatusResponse?,
        recordResult: Boolean,
        attemptId: String = callLifecycle.currentAttemptId()
    ) {
        val finalization = callLifecycle.tryFinalize(
            attemptId = attemptId,
            remoteCallId = finalStatus?.callId.orEmpty()
        ) ?: return
        if (recordResult) {
            recordResult(finalStatus, finalization.recordCallId)
        }
        clearRuntimeState(stopAudioSocket = true)
        seconds = 0
        muted = false
        speaker = true
        panelCollapsed = false
        callbacks.onNavigateAfterExit(finalization.origin)
    }

    fun toggleMute() {
        muted = !muted
        audioClient.setMicrophoneMuted(muted)
    }

    fun toggleSpeaker() {
        speaker = !speaker
        audioClient.setSpeakerphoneEnabled(speaker)
    }

    fun togglePanel() {
        panelCollapsed = !panelCollapsed
    }

    fun applyToCallPageArgs(args: CallPageArgs) {
        args.translateCallSeconds = seconds
        args.translationCallStatus = status
        args.translationCallError = error
        args.translationAudioChannelStatus = audioChannelStatus
        args.translateCallMuted = muted
        args.translateCallSpeaker = speaker
        args.translateCallPanelCollapsed = panelCollapsed
        args.onTranslateMuteToggle = ::toggleMute
        args.onTranslateSpeakerToggle = ::toggleSpeaker
        args.onTranslatePanelToggle = ::togglePanel
        args.onTranslateHangup = ::hangupAndExit
    }

    fun tickConnectedSecond() {
        seconds += 1
    }

    fun shouldKeepScreenOn(currentPage: FinalPage): Boolean {
        val callState = status?.callState.orEmpty()
        val finished = callState.equals("ENDED", ignoreCase = true) ||
            callState.equals("FAILED", ignoreCase = true)
        return currentPage == FinalPage.TranslateCall &&
            !finished &&
            (starting || callId.isNotBlank() || status != null)
    }

    suspend fun pollWhileActive(currentPageProvider: () -> FinalPage) {
        val activeCallId = callId
        val activeAttemptId = callLifecycle.currentAttemptId()
        val activeUserId = resolvedUserId()
        if (currentPageProvider() != FinalPage.TranslateCall || activeCallId.isBlank()) {
            return
        }
        while (currentPageProvider() == FinalPage.TranslateCall &&
            callId == activeCallId &&
            callLifecycle.isActive(activeAttemptId)
        ) {
            val statusResult = runCatching {
                deps.repository.getTranslationCallStatus(
                    TranslationCallStatusRequest(
                        userId = activeUserId,
                        callId = activeCallId
                    )
                )
            }
            if (!callLifecycle.isActive(activeAttemptId)) {
                break
            }
            if (statusResult.isFailure) {
                error = statusResult.exceptionOrNull()?.message ?: "获取实时翻译通话状态失败"
                error = localizeTranslationCallStatusText(error)
                delay(1000L)
                continue
            }
            val currentStatus = statusResult.getOrThrow()
            val previousStatus = status
            starting = false
            status = currentStatus
            recordTranslationStatus(previousStatus, currentStatus)
            val statusPlan = TranslationCallPolledStatusPolicy.apply(
                currentStatus = currentStatus,
                previousError = error
            )
            if (statusPlan.audioChannelStatus != null) {
                audioChannelStatus = statusPlan.audioChannelStatus
            }
            if (statusPlan.error != null) {
                error = statusPlan.error
            }
            if (statusPlan.shouldExit) {
                exitPage(
                    finalStatus = currentStatus,
                    recordResult = true,
                    attemptId = activeAttemptId
                )
                break
            }
            delay(1000L)
        }
    }

    private fun recordResult(
        finalStatus: TranslationCallStatusResponse?,
        recordCallId: String
    ) {
        val snapshot = finalStatus ?: status ?: return
        val targetNumber = callbacks.lastDialedNumber()
            .ifBlank { callbacks.dialInput() }
            .ifBlank { "未知号码" }
        val occurredAtMillis = System.currentTimeMillis()
        val callState = snapshot.callState.uppercase(Locale.ROOT)
        val success = callState == "ENDED"
        val statusLabel = when {
            success -> "实时翻译通话"
            callState == "FAILED" -> "翻译通话失败"
            else -> "翻译通话"
        }
        val summary = localizeTranslationCallStatusText(snapshot.statusMessage).ifBlank {
            if (success) {
                "刚刚 · 实时翻译通话结束，时长 ${formatSeconds(seconds)}"
            } else {
                "刚刚 · 通话状态 ${snapshot.callState}"
            }
        }
        callbacks.onAppendCallRecordIfAbsent(
            FinalCallRecord(
                title = "翻译通话 ${formatDialNumber(targetNumber)}",
                status = statusLabel,
                meta = summary,
                success = success,
                occurredAtMillis = occurredAtMillis,
                phoneNumber = targetNumber,
                durationText = formatSeconds(seconds),
                resultText = summary,
                callId = recordCallId,
                callKind = DialCallKind.TRANSLATION
            )
        )
    }

    private fun applyAudioSocketEvent(event: TranslationCallAudioSocketClient.Event) {
        when (event) {
            is TranslationCallAudioSocketClient.Event.Connected -> {
                recordAudioRuntimeEvent(TranslationRuntimeAudioEvent.Connected)
                audioChannelStatus = "翻译音频通道已连接"
            }
            is TranslationCallAudioSocketClient.Event.Status -> {
                recordAudioRuntimeEvent(TranslationRuntimeAudioEvent.Status, event.message)
                audioChannelStatus = localizeTranslationCallStatusText(event.message)
            }
            is TranslationCallAudioSocketClient.Event.Error -> {
                recordAudioRuntimeEvent(TranslationRuntimeAudioEvent.Error, event.message)
                audioChannelStatus = localizeTranslationCallStatusText(event.message)
                error = localizeTranslationCallStatusText(event.message)
            }
            TranslationCallAudioSocketClient.Event.Closed -> {
                recordAudioRuntimeEvent(TranslationRuntimeAudioEvent.Closed)
                audioChannelStatus = "翻译音频通道已关闭"
            }
        }
    }

    private fun recordTranslationStatus(
        previous: TranslationCallStatusResponse?,
        current: TranslationCallStatusResponse,
        eventTypeOverride: String? = null,
        reasonOverride: String? = null,
        throwable: Throwable? = null
    ) = translationRuntimeRecorder.recordStatus(
        previous,
        current,
        eventTypeOverride,
        reasonOverride,
        throwable
    )

    private fun recordAudioRuntimeEvent(kind: TranslationRuntimeAudioEvent, message: String? = null) {
        translationRuntimeRecorder.recordAudio(kind, callId, status, starting, message)
    }

    private fun recordUserHangupRuntimeEvent() {
        translationRuntimeRecorder.recordUserHangup(callId, status, starting)
    }

    private fun recordLifecycleCancelledRuntimeEvent(reason: String) {
        translationRuntimeRecorder.recordLifecycleCancelled(reason, callId, status, starting)
    }

    private fun resolvedUserId(): String {
        return AccountIdentityProvider.accountId.ifBlank { "default-user" }
    }
}

internal class AssistantTranslationCallRuntimeState(
    val audioClient: TranslationCallAudioSocketClient,
    val seconds: MutableState<Int>,
    val muted: MutableState<Boolean>,
    val speaker: MutableState<Boolean>,
    val panelCollapsed: MutableState<Boolean>,
    val callId: MutableState<String>,
    val status: MutableState<TranslationCallStatusResponse?>,
    val error: MutableState<String?>,
    val audioChannelStatus: MutableState<String?>,
    val starting: MutableState<Boolean>,
    val audioPermissionGrantedSignal: MutableState<Long>,
    val lifecycleAttemptId: MutableState<String>,
    val lifecycleOrigin: MutableState<String>,
    val lifecycleFinalized: MutableState<Boolean>
)

internal data class AssistantTranslationCallRuntimeDeps(
    val repository: AssistantRepository,
    val scope: CoroutineScope
)

internal data class AssistantTranslationCallRuntimeCallbacks(
    val dialInput: () -> String,
    val onDialInputChange: (String) -> Unit,
    val lastDialedNumber: () -> String,
    val onLastDialedNumberChange: (String) -> Unit,
    val onShowCallsDialSheetChange: (Boolean) -> Unit,
    val translationProvider: () -> String?,
    val translationQwenVoicePreference: () -> String,
    val translationQwenLanguageSettings: () -> TranslationProviderLanguageSettings,
    val onAppendCallRecordIfAbsent: (FinalCallRecord) -> Unit,
    val onNavigateToTranslateCall: () -> Unit,
    val onNavigateAfterExit: (TranslationCallOrigin) -> Unit,
    val dialTarget: () -> String = { "" }
)
