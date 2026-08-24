package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.SharedPreferences
import android.widget.Toast
import com.vvtech.aiassistant.features.assistant_voice_clone.AssistantVoiceCloneRecordingController
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneAvailabilityPolicy
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneRecordingWatchdog
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneUploadPolicy
import com.vvtech.aiassistant.features.assistant_voice_clone.logVoiceCloneRuntime
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.AliyunIdProSdkAdapter
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentCoordinator
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentState
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentStep
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentUiArgs
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSnapshot
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceTracker
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneCameraCallbacks
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.repository.TaskRepository
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class AssistantVoiceCloneRuntimeController(
    private val deps: AssistantVoiceCloneRuntimeDeps,
    private val state: AssistantVoiceCloneRuntimeState,
    private val recordingController: AssistantVoiceCloneRecordingController,
    private val enrollmentCoordinator: VoiceCloneEnrollmentCoordinator,
    private val completionActivationHandler: VoiceCloneCompletionActivationHandler,
    private val flowOpenHandler: AssistantVoiceCloneFlowOpenHandler
) {
    private var submissionPollJob: Job? = null
    var callbacks: AssistantVoiceCloneRuntimeCallbacks = AssistantVoiceCloneRuntimeCallbacks({}, {})

    var guideSkipped: Boolean
        get() = state.guideSkipped.value
        set(value) {
            state.guideSkipped.value = value
        }
    var guideDisabled: Boolean
        get() = state.guideDisabled.value
        set(value) {
            state.guideDisabled.value = value
        }
    var forceGuide: Boolean
        get() = state.forceGuide.value
        set(value) {
            state.forceGuide.value = value
        }
    var showGuide: Boolean
        get() = state.showGuide.value
        set(value) {
            state.showGuide.value = value
        }
    var status: VoiceCloneStatusResponse?
        get() = state.status.value
        set(value) {
            state.status.value = value
        }
    var scripts: List<VoiceCloneScriptItem>
        get() = state.scripts.value
        set(value) {
            state.scripts.value = value
        }
    var scriptsVersion: String
        get() = state.scriptsVersion.value
        set(value) {
            state.scriptsVersion.value = value
        }
    var loading: Boolean
        get() = state.loading.value
        set(value) {
            state.loading.value = value
        }
    var uploading: Boolean
        get() = state.uploading.value
        set(value) {
            state.uploading.value = value
        }
    var actionLoading: Boolean
        get() = state.actionLoading.value
        set(value) {
            state.actionLoading.value = value
        }
    var error: String?
        get() = state.error.value
        set(value) {
            state.error.value = value
        }
    var samples: Map<String, VoiceCloneLocalSample>
        get() = state.samples.value
        set(value) {
            state.samples.value = value
        }
    var recordingScriptId: String?
        get() = state.recordingScriptId.value
        set(value) {
            state.recordingScriptId.value = value
        }
    var pendingRecordScriptId: String?
        get() = state.pendingRecordScriptId.value
        set(value) {
            state.pendingRecordScriptId.value = value
        }
    var rerecordMode: Boolean
        get() = state.rerecordMode.value
        set(value) {
            state.rerecordMode.value = value
        }
    var submissionState: VoiceCloneSubmissionState
        get() = state.submissionState.value
        set(value) {
            state.submissionState.value = value
        }
    var currentScriptIndex: Int
        get() = state.currentScriptIndex.value
        set(value) {
            state.currentScriptIndex.value = value
        }
    val statusInput: VoiceCloneStatusInput
        get() = VoiceCloneStatusInput(status, loading, error)
    val recordingInput: VoiceCloneRecordingInput
        get() = VoiceCloneRecordingInput(
            scripts,
            samples,
            uploading,
            actionLoading,
            recordingScriptId,
            VoiceCloneFaceUiArgs(
                snapshot = state.facePresence.value,
                callbacks = VoiceCloneCameraCallbacks(
                    onCameraReady = recordingController::onCameraReady,
                    onFaceSample = recordingController::onFaceSample,
                    onCameraFailure = recordingController::onCameraFailure
                )
            )
        )
    val guideInput: VoiceCloneGuideInput
        get() = VoiceCloneGuideInput(
            voiceCloneEnrollment = VoiceCloneEnrollmentUiArgs(
                state = enrollmentCoordinator.state,
                onAgreementChange = enrollmentCoordinator::setAgreement,
                onContinueConsent = enrollmentCoordinator::continueAfterConsent,
                onIdentityChange = enrollmentCoordinator::updateIdentity,
                onIdentityEditStarted = enrollmentCoordinator::beginIdentityEdit, onPrepareVerification = enrollmentCoordinator::prepareVerification,
                onConfirmReplacement = enrollmentCoordinator::confirmReplacement,
                onDismissReplacement = enrollmentCoordinator::dismissReplacement,
                onStartVerification = enrollmentCoordinator::startVerification,
                onVerificationPermissionDenied = {
                    enrollmentCoordinator.reset(currentAppText(
                        "人脸跟读认证需要摄像头和麦克风权限，请重新开始。",
                        "Face and read-aloud verification needs camera and microphone permissions. Please start again."
                    ))
                }
            ),
            voiceCloneSubmissionState = submissionState,
            voiceCloneCurrentScriptIndex = currentScriptIndex
        )

    fun callbacksInput(requestAudioPermission: () -> Unit): VoiceCloneCallbacksInput = VoiceCloneCallbacksInput(
        onRefreshVoiceCloneStatus = ::refreshStatus,
        onSelectAiVoiceForCalls = ::selectAiVoiceForCalls,
        onSelectCloneVoiceForCalls = ::selectCloneVoiceForCalls,
        onOpenVoiceCloneFlow = { resetRecording -> openFlow(resetRecording = resetRecording) },
        onVoiceCloneRecord = { script -> requestRecord(script, requestAudioPermission) },
        onVoiceCloneStop = ::finishRecording,
        onSubmitVoiceCloneRecording = ::submitRecording,
        onVoiceCloneRerecord = {
            if (!uploading && !actionLoading) {
                if (submissionState == VoiceCloneSubmissionState.READY) {
                    terminateAndReset()
                } else {
                    terminateAndReset()
                    rerecordMode = true
                }
            }
        },
        onStartUsingVoiceClone = ::startUsingVoiceClone,
        onVoiceCloneLifecycleInterrupted = {
            terminateAndReset(currentAppText(
                "应用进入后台，本次采集已结束，请重新开始。",
                "The app went to the background, so this collection ended. Please start again."
            ))
        }
    )

    fun refreshStatus() {
        if (loading) { logVoiceCloneRuntime("VOICE_CLONE_REFRESH_SKIPPED", result = "skipped", reason = "already_loading"); return }
        deps.scope.launch {
            logVoiceCloneRuntime("VOICE_CLONE_REFRESH_STARTED", statusValue = status?.status)
            loading = true
            error = null
            runCatching {
                deps.taskRepository.getVoiceCloneStatus()
            }.onSuccess { nextStatus ->
                status = nextStatus
                currentScriptIndex = 0
                if (submissionState == VoiceCloneSubmissionState.PROCESSING ||
                    submissionState == VoiceCloneSubmissionState.UNKNOWN
                ) {
                    submissionState = VoiceCloneUploadPolicy.toSubmissionState(nextStatus.status)
                }
                if (nextStatus.status.uppercase(Locale.ROOT) == "EXPIRED" && nextStatus.lastError.isNotBlank()) {
                    error = nextStatus.lastError
                }
                logVoiceCloneRuntime("VOICE_CLONE_REFRESH_COMPLETED", "success", statusValue = nextStatus.status)
            }.onFailure { throwable ->
                error = throwable.message ?: "Voice clone status load failed"
                logVoiceCloneRuntime("VOICE_CLONE_REFRESH_FAILED", "failed", statusValue = status?.status, throwable = throwable)
            }
            loading = false
        }
    }

    fun clearDraft(deleteFiles: Boolean = true) = recordingController.clearDraft(deleteFiles)
    fun onRealtimeProviderChanged() {
        clearDraft()
        rerecordMode = false
        refreshStatus()
    }
    fun requestRecord(script: VoiceCloneScriptItem, requestAudioPermission: () -> Unit) =
        recordingController.requestRecord(script, requestAudioPermission)
    fun onRecordAudioPermissionResult(granted: Boolean) =
        recordingController.onRecordAudioPermissionResult(granted)
    fun beginRecording(script: VoiceCloneScriptItem) = recordingController.beginRecording(script)
    fun finishRecording(script: VoiceCloneScriptItem) = recordingController.finishRecording(script)
    fun togglePreview(script: VoiceCloneScriptItem) = recordingController.togglePreview(script)
    fun uploadSamples() {
        if (uploading) { logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_SKIPPED", "skipped", "already_uploading", status?.status); return }
        if (recordingScriptId != null) {
            error = currentAppText("请先结束当前录音，再提交样本。", "Finish the current recording before submitting samples.")
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_BLOCKED", "blocked", "recording_active", status?.status)
            return
        }
        val primaryScript = scripts.firstOrNull()
        if (primaryScript == null) {
            error = currentAppText("当前没有可用的录音脚本。", "No recording script is available.")
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_BLOCKED", "blocked", "script_missing", status?.status)
            return
        }
        val primarySample = samples[primaryScript.scriptId]
        if (primarySample == null) {
            error = currentAppText("请先完成录音后再提交。", "Complete the recording before submitting.")
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_BLOCKED", "blocked", "sample_missing", status?.status)
            return
        }
        if (primarySample.qualityBlocked) {
            error = primarySample.qualityWarnings.firstOrNull()
                ?: currentAppText("录音质量未达标，请重新录制。", "Recording quality is too low. Please record again.")
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_BLOCKED", "blocked", "quality_blocked", status?.status)
            return
        }
        val enrollment = enrollmentCoordinator.state
        val attemptId = enrollment.attemptId
        val collectionId = enrollment.collection?.collectionId
        if (attemptId.isNullOrBlank() || collectionId.isNullOrBlank()) {
            error = currentAppText(
                "认证或采集会话已失效，请重新开始。",
                "The verification or collection session expired. Please start again."
            )
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_BLOCKED", "blocked", "correlation_missing")
            return
        }
        val facePresence = state.facePresence.value.summary
        deps.scope.launch {
            logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_STARTED", statusValue = status?.status, attemptId = attemptId, collectionId = collectionId)
            uploading = true
            submissionState = VoiceCloneSubmissionState.SUBMITTING
            error = null
            runCatching {
                val response = deps.taskRepository.uploadVoiceCloneSamples(
                    VoiceCloneUploadRequestFactory.create(
                        attemptId = attemptId,
                        collectionId = collectionId,
                        scriptVersion = scriptsVersion,
                        script = primaryScript,
                        sample = primarySample,
                        facePresence = facePresence
                    )
                )
                check(VoiceCloneUploadPolicy.isAcceptedProviderStatus(response.status)) {
                    currentAppText(
                        "声音克隆供应商未接受本次录音",
                        "The voice cloning provider did not accept this recording."
                    )
                }
                response
            }.onSuccess { nextStatus ->
                val nextSubmissionState = VoiceCloneUploadPolicy.toSubmissionState(nextStatus.status)
                status = nextStatus
                rerecordMode = false
                clearDraft()
                submissionState = nextSubmissionState
                currentScriptIndex = 0
                if (nextSubmissionState == VoiceCloneSubmissionState.PROCESSING) {
                    startSubmissionPolling()
                }
                logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_COMPLETED", "success", statusValue = nextStatus.status, attemptId = attemptId, collectionId = collectionId)
                toast(
                    when (nextSubmissionState) {
                        VoiceCloneSubmissionState.READY -> currentAppText(
                            "声音克隆已生成，可手动启用。",
                            "Voice clone is ready. You can enable it manually."
                        )
                        VoiceCloneSubmissionState.PROCESSING -> currentAppText(
                            "录音已提交，正在生成声音。",
                            "Recording submitted. Your voice is being generated."
                        )
                        else -> currentAppText(
                            "声音提交状态异常，请稍后查看。",
                            "Voice submission status is abnormal. Please check later."
                        )
                    }
                )
            }.onFailure { throwable ->
                clearDraft()
                val message = throwable.message ?: currentAppText(
                    "采集失败，请重新开始。",
                    "Collection failed. Please start again."
                )
                submissionState = if (message.contains("提交结果确认中")) {
                    VoiceCloneSubmissionState.UNKNOWN
                } else {
                    VoiceCloneSubmissionState.FAILED
                }
                error = message
                logVoiceCloneRuntime("VOICE_CLONE_UPLOAD_FAILED", "failed", statusValue = status?.status, throwable = throwable, attemptId = attemptId, collectionId = collectionId)
            }
            uploading = false
        }
    }

    fun submitRecording() {
        val primaryScript = scripts.firstOrNull()
        if (primaryScript == null) {
            error = currentAppText("当前没有可提交的录音脚本。", "No recording script can be submitted.")
            return
        }
        val currentSample = samples[primaryScript.scriptId]
        if (currentSample == null) {
            error = currentAppText("请先完成录音后再提交。", "Complete the recording before submitting.")
            return
        }
        if (currentSample.qualityBlocked) {
            error = currentSample.qualityWarnings.firstOrNull()
                ?: currentAppText("录音质量未达标，请重新录制。", "Recording quality is too low. Please record again.")
            return
        }
        currentScriptIndex = 0
        uploadSamples()
    }

    fun setActive(active: Boolean) {
        if (actionLoading) { logVoiceCloneRuntime("VOICE_CLONE_ACTIVE_CHANGE_SKIPPED", "skipped", "already_loading", status?.status); return }
        deps.scope.launch {
            logVoiceCloneRuntime("VOICE_CLONE_ACTIVE_CHANGE_STARTED", statusValue = status?.status, attributes = mapOf("requestedActive" to active.toString()))
            actionLoading = true
            error = null
            runCatching {
                if (active) deps.taskRepository.activateVoiceClone() else deps.taskRepository.deactivateVoiceClone()
            }.onSuccess { nextStatus ->
                status = nextStatus
                logVoiceCloneRuntime("VOICE_CLONE_ACTIVE_CHANGE_COMPLETED", "success", nextStatus.status, attributes = mapOf("active" to nextStatus.active.toString()))
                toast(if (active) {
                    currentAppText("已切换为我的克隆音色", "Switched to my cloned voice")
                } else {
                    currentAppText("已切换为 AI 声音", "Switched to AI voice")
                })
            }.onFailure { throwable ->
                error = throwable.message ?: if (active) {
                    currentAppText("启用克隆音色失败", "Failed to enable cloned voice")
                } else {
                    currentAppText("切换 AI 声音失败", "Failed to switch to AI voice")
                }
                logVoiceCloneRuntime("VOICE_CLONE_ACTIVE_CHANGE_FAILED", "failed", throwable = throwable, attributes = mapOf("requestedActive" to active.toString()))
            }
            actionLoading = false
        }
    }
    fun openFlow(resetRecording: Boolean = false) =
        flowOpenHandler.open(resetRecording, ::openAvailableFlow, ::toast)

    private fun openAvailableFlow(resetRecording: Boolean) {
        enrollmentCoordinator.reset()
        if (FinalVoiceCloneFeatureVisible) {
            refreshStatus()
        }
        submissionState = VoiceCloneSubmissionState.IDLE
        error = null
        if (resetRecording) {
            clearDraft()
            rerecordMode = true
        }
        callbacks.onOpenVoiceCloneSettings()
    }

    fun selectAiVoiceForCalls() {
        if (status?.active == true) {
            setActive(false)
        } else {
            toast(currentAppText("已切换为 AI 声音", "Switched to AI voice"))
        }
    }

    fun selectCloneVoiceForCalls() {
        val currentStatus = status
        val ready = currentStatus?.status?.uppercase(Locale.ROOT) == "READY"
        when {
            currentStatus?.active == true && ready -> Unit
            ready -> setActive(true)
            finalHasUploadedVoiceClone(currentStatus) -> toast(currentAppText(
                "克隆音色正在生成中，请稍后再试",
                "Your cloned voice is still being generated. Please try again later."
            ))
            else -> openFlow(resetRecording = true)
        }
    }

    fun startUsingVoiceClone(improvementConsent: Boolean) =
        completionActivationHandler.activate(
            improvementConsent, ::toast, callbacks.onOpenVoiceIdentitySettings
        )

    fun shouldShowGuideForPendingEntry(pendingActive: Boolean, resumeExisting: Boolean): Boolean {
        if (!pendingActive) return false
        if (!FinalVoiceCloneFeatureVisible) return false
        if (!VoiceCloneAvailabilityPolicy.canEnroll(status)) return false
        if (resumeExisting) return false
        return forceGuide || (!guideDisabled && !guideSkipped && !finalHasUploadedVoiceClone(status))
    }

    fun startGuide() {
        showGuide = false
        guideSkipped = true
        openFlow(resetRecording = false)
    }

    fun dismissGuide() {
        showGuide = false
        guideSkipped = true
    }

    fun neverAskGuide() {
        showGuide = false
        guideSkipped = true
        guideDisabled = true
        deps.prefs.edit().putBoolean(FinalVoiceCloneGuideDisabledKey, true).apply()
    }

    fun resetGuide() {
        guideSkipped = false
        guideDisabled = false
        deps.prefs.edit().remove(FinalVoiceCloneGuideDisabledKey).apply()
    }

    fun resetPageStateOnLeave() {
        terminateAndReset()
    }

    fun onMfvcCloneAccepted(nextStatus: VoiceCloneStatusResponse) {
        val nextSubmissionState = VoiceCloneUploadPolicy.toSubmissionState(nextStatus.status)
        status = nextStatus
        clearDraft()
        rerecordMode = false
        submissionState = nextSubmissionState
        currentScriptIndex = 0
        if (nextSubmissionState == VoiceCloneSubmissionState.PROCESSING) {
            startSubmissionPolling()
        }
        toast(
            when (nextSubmissionState) {
                VoiceCloneSubmissionState.READY -> currentAppText(
                    "声音克隆已生成，可手动启用。",
                    "Voice clone is ready. You can enable it manually."
                )
                VoiceCloneSubmissionState.PROCESSING -> currentAppText(
                    "跟读已提交，正在生成克隆音色。",
                    "Read-aloud sample submitted. Your cloned voice is being generated."
                )
                else -> currentAppText(
                    "声音克隆状态异常，请重新开始。",
                    "Voice clone status is abnormal. Please start again."
                )
            }
        )
    }

    fun disposeResources() {
        submissionPollJob?.cancel()
        submissionPollJob = null
        enrollmentCoordinator.reset()
        recordingController.disposeResources()
    }

    fun terminateAndReset(message: String? = null) {
        submissionPollJob?.cancel()
        submissionPollJob = null
        recordingController.terminateCapture()
        enrollmentCoordinator.reset(message)
        scripts = emptyList()
        scriptsVersion = ""
        uploading = false
        error = null
        submissionState = VoiceCloneSubmissionState.IDLE
        currentScriptIndex = 0
        rerecordMode = false
    }

    private fun startSubmissionPolling() {
        submissionPollJob?.cancel()
        submissionPollJob = deps.scope.launch {
            repeat(MAX_SUBMISSION_POLLS) {
                delay(SUBMISSION_POLL_INTERVAL_MS)
                val nextStatus = runCatching { deps.taskRepository.getVoiceCloneStatus() }
                    .getOrNull() ?: return@repeat
                status = nextStatus
                when (val next = VoiceCloneUploadPolicy.toSubmissionState(nextStatus.status)) {
                    VoiceCloneSubmissionState.READY,
                    VoiceCloneSubmissionState.FAILED,
                    VoiceCloneSubmissionState.UNKNOWN -> {
                        submissionState = next
                        return@launch
                    }
                    else -> submissionState = VoiceCloneSubmissionState.PROCESSING
                }
            }
            submissionState = VoiceCloneSubmissionState.UNKNOWN
            error = currentAppText(
                "声音生成状态查询超时，请稍后在语音设置中查看。",
                "Voice generation status timed out. Check voice settings later."
            )
        }
    }

    private fun toast(message: String) = Toast.makeText(deps.context, message, Toast.LENGTH_SHORT).show()
    private companion object {
        const val MAX_SUBMISSION_POLLS = 60
        const val SUBMISSION_POLL_INTERVAL_MS = 2_000L
    }
}
