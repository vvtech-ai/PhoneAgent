package com.vvtech.aiassistant.features.assistant_voice_clone
import android.content.Context
import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant.AssistantVoiceCloneRuntimeState
import com.vvtech.aiassistant.features.assistant.VoiceCloneAudioPreviewPlayer
import com.vvtech.aiassistant.features.assistant.VoiceCloneAudioQualityAnalyzer
import com.vvtech.aiassistant.features.assistant.VoiceCloneLocalSample
import com.vvtech.aiassistant.features.assistant.VoiceCloneRecorder
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceTracker
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceFailure
import java.io.File

internal class AssistantVoiceCloneRecordingController(
    private val context: Context,
    private val state: AssistantVoiceCloneRuntimeState,
    private val recorder: VoiceCloneRecorder,
    private val previewPlayer: VoiceCloneAudioPreviewPlayer,
    private val facePresenceTracker: FacePresenceTracker,
    private val watchdog: VoiceCloneRecordingWatchdog
) {
    var onCollectionInvalidated: () -> Unit = {}
    var onTerminalInterrupted: (String) -> Unit = {}

    fun clearDraft(deleteFiles: Boolean = true) {
        state.pendingRecordScriptId.value = null
        previewPlayer.stop()
        state.playingScriptId.value = null
        if (state.recordingScriptId.value != null) {
            watchdog.stop()
            recorder.cancel()
            state.recordingScriptId.value = null
        }
        if (deleteFiles) {
            state.samples.value.values.forEach { sample ->
                File(sample.filePath).takeIf(File::exists)?.delete()
            }
        }
        state.samples.value = emptyMap()
        state.error.value = null
        state.submissionState.value = VoiceCloneSubmissionState.IDLE
        state.currentScriptIndex.value = 0
        prepareCollection()
    }

    fun requestRecord(script: VoiceCloneScriptItem, requestAudioPermission: () -> Unit) {
        if (state.recordingScriptId.value != null && state.recordingScriptId.value != script.scriptId) {
            state.error.value = currentAppText(
                "请先结束当前录音，再开始下一条脚本",
                "Finish the current recording before starting another script."
            )
            logVoiceCloneRuntime("VOICE_CLONE_RECORDING_BLOCKED", "blocked", "another_recording_active")
            return
        }
        if (isRecordAudioGranted()) {
            beginRecording(script)
        } else {
            state.pendingRecordScriptId.value = script.scriptId
            logVoiceCloneRuntime("VOICE_CLONE_MIC_PERMISSION_REQUESTED", attributes = scriptRef(script))
            requestAudioPermission()
        }
    }

    fun onRecordAudioPermissionResult(granted: Boolean) {
        val scriptId = state.pendingRecordScriptId.value
        state.pendingRecordScriptId.value = null
        logVoiceCloneRuntime(
            "VOICE_CLONE_MIC_PERMISSION_RESULT",
            if (granted) "granted" else "denied",
            attributes = mapOf("scriptRef" to voiceCloneLogRef(scriptId))
        )
        if (granted) {
            state.scripts.value.firstOrNull { it.scriptId == scriptId }?.let(::beginRecording)
                ?: run {
                    state.error.value = currentAppText(
                        "录音脚本已失效，请刷新页面后重试",
                        "The recording script expired. Refresh the page and try again."
                    )
                }
        } else {
            onTerminalInterrupted(currentAppText(
                "麦克风权限未授予，本次采集已结束，请重新开始。",
                "Microphone permission was not granted. This capture has ended. Please start again."
            ))
        }
    }

    fun beginRecording(script: VoiceCloneScriptItem) {
        if (!facePresenceTracker.startRecording(SystemClock.elapsedRealtime())) {
            state.error.value = currentAppText(
                "请确保前置镜头中只有一人并保持清晰可见。",
                "Make sure only one person is clearly visible in the front camera."
            )
            logVoiceCloneRuntime("VOICE_CLONE_RECORDING_BLOCKED", "blocked", "face_not_ready", attributes = scriptRef(script))
            return
        }
        syncFacePresence()
        runCatching {
            recorder.start(script.scriptId)
        }.onSuccess {
            state.recordingScriptId.value = script.scriptId
            state.error.value = null
            watchdog.start(::onWatchdogTick)
            logVoiceCloneRuntime("VOICE_CLONE_RECORDING_STARTED", "success", attributes = scriptRef(script))
        }.onFailure { throwable ->
            facePresenceTracker.cancelRecording()
            syncFacePresence()
            state.pendingRecordScriptId.value = null
            state.recordingScriptId.value = null
            logVoiceCloneRuntime("VOICE_CLONE_RECORDING_START_FAILED", "failed", throwable = throwable, attributes = scriptRef(script))
            onTerminalInterrupted(throwable.message ?: currentAppText(
                "录音启动失败，请重新开始。",
                "Recording failed to start. Please start again."
            ))
        }
    }

    fun finishRecording(script: VoiceCloneScriptItem) {
        watchdog.stop()
        runCatching {
            recorder.stop()
        }.onSuccess { result ->
            state.recordingScriptId.value = null
            val facePresence = facePresenceTracker.finish(SystemClock.elapsedRealtime())
            syncFacePresence()
            previewPlayer.stop()
            state.playingScriptId.value = null
            if (facePresence.failure != null) {
                result.file.delete()
                state.error.value = currentAppText(
                    "采集失败，请保持单人正对镜头后重新录制。",
                    "Collection failed. Keep one person facing the camera and record again."
                )
                logVoiceCloneRuntime("VOICE_CLONE_RECORDING_REJECTED", "blocked", facePresence.failure.name, attributes = recordingMetrics(script, result.durationMs))
                onCollectionInvalidated()
            } else if (result.durationMs < script.minDurationSeconds * 1000L) {
                result.file.delete()
                logVoiceCloneRuntime("VOICE_CLONE_RECORDING_REJECTED", "blocked", "duration_too_short", attributes = recordingMetrics(script, result.durationMs))
                invalidateCollection(currentAppText(
                    "录音时长过短，已更换短句，请重新录制。",
                    "Recording is too short. A shorter script was selected; please record again."
                ))
            } else {
                val qualityReport = VoiceCloneAudioQualityAnalyzer.analyze(
                    result.file,
                    script.minDurationSeconds,
                    script.targetDurationSeconds
                )
                if (qualityReport.blocked) {
                    result.file.delete()
                    logVoiceCloneRuntime("VOICE_CLONE_RECORDING_REJECTED", "blocked", "audio_quality", attributes = recordingMetrics(script, result.durationMs))
                    invalidateCollection(
                        qualityReport.blockedReason ?: currentAppText(
                            "录音质量未达标，已更换短句，请重新录制。",
                            "Recording quality is too low. A shorter script was selected; please record again."
                        )
                    )
                } else {
                    state.error.value = null
                    state.samples.value[script.scriptId]?.let { previous ->
                        File(previous.filePath).takeIf(File::exists)?.delete()
                    }
                    state.samples.value = state.samples.value + (
                        script.scriptId to VoiceCloneLocalSample(
                            scriptId = script.scriptId,
                            text = script.text,
                            filePath = result.file.absolutePath,
                            durationMs = result.durationMs,
                            qualityWarnings = qualityReport.warnings,
                            qualityBlocked = false
                        )
                    )
                    logVoiceCloneRuntime(
                        "VOICE_CLONE_RECORDING_COMPLETED",
                        "success",
                        attributes = recordingMetrics(script, result.durationMs) +
                            mapOf("warningCount" to qualityReport.warnings.size.toString())
                    )
                }
            }
        }.onFailure { throwable ->
            state.recordingScriptId.value = null
            logVoiceCloneRuntime("VOICE_CLONE_RECORDING_STOP_FAILED", "failed", throwable = throwable, attributes = scriptRef(script))
            onTerminalInterrupted(throwable.message ?: currentAppText(
                "录音结束失败，请重新开始。",
                "Recording failed to finish. Please start again."
            ))
        }
    }

    fun togglePreview(script: VoiceCloneScriptItem) {
        val sample = state.samples.value[script.scriptId] ?: return
        runCatching {
            previewPlayer.toggle(sample.filePath) {
                state.playingScriptId.value = null
            }
        }.onSuccess { playing ->
            state.playingScriptId.value = if (playing) script.scriptId else null
            if (playing) {
                state.error.value = null
            }
        }.onFailure { throwable ->
            state.playingScriptId.value = null
            state.error.value = throwable.message ?: currentAppText("试听失败，请重试", "Preview failed. Please try again.")
        }
    }

    fun onCameraReady() {
        facePresenceTracker.onCameraReady()
        syncFacePresence()
        logVoiceCloneRuntime("VOICE_CLONE_CAMERA_READY", "success")
    }

    fun onFaceSample(timestampMs: Long, faceCount: Int) {
        val wasRecording = facePresenceTracker.snapshot.recording
        val next = facePresenceTracker.onSample(timestampMs, faceCount)
        syncFacePresence()
        if (wasRecording && next.failure != null) {
            logVoiceCloneRuntime("VOICE_CLONE_FACE_GATE_FAILED", "blocked", next.failure.name)
            abortForFacePresence(next.failure)
        }
    }

    fun onCameraFailure() {
        val wasRecording = facePresenceTracker.snapshot.recording
        facePresenceTracker.onCameraUnavailable()
        syncFacePresence()
        if (wasRecording) watchdog.stop()
        logVoiceCloneRuntime("VOICE_CLONE_CAMERA_FAILED", "failed", "camera_unavailable")
        onTerminalInterrupted(currentAppText(
            "相机不可用，本次采集已结束，请重新开始。",
            "Camera is unavailable. This capture has ended. Please start again."
        ))
    }

    fun prepareCollection() {
        facePresenceTracker.prepareCollection()
        syncFacePresence()
    }

    fun resetPageStateOnLeave() {
        terminateCapture()
        state.rerecordMode.value = false
    }

    fun disposeResources() {
        terminateCapture()
    }

    fun terminateCapture() {
        watchdog.stop()
        previewPlayer.stop()
        recorder.cancel()
        state.pendingRecordScriptId.value = null
        state.recordingScriptId.value = null
        state.playingScriptId.value = null
        state.samples.value.values.forEach { sample ->
            File(sample.filePath).takeIf(File::exists)?.delete()
        }
        state.samples.value = emptyMap()
        state.submissionState.value = VoiceCloneSubmissionState.IDLE
        facePresenceTracker.reset()
        syncFacePresence()
    }

    private fun onWatchdogTick(timestampMs: Long) {
        val next = facePresenceTracker.onWatchdogTick(timestampMs)
        syncFacePresence()
        if (next.failure == FacePresenceFailure.ANALYSIS_STALLED) {
            watchdog.stop()
            recorder.cancel()
            logVoiceCloneRuntime("VOICE_CLONE_FACE_GATE_FAILED", "blocked", FacePresenceFailure.ANALYSIS_STALLED.name)
            onTerminalInterrupted(currentAppText(
                "摄像头检测中断，本次采集已结束，请重新开始。",
                "Camera detection was interrupted. This capture has ended. Please start again."
            ))
        }
    }

    private fun abortForFacePresence(
        failure: FacePresenceFailure
    ) {
        watchdog.stop()
        recorder.cancel()
        state.pendingRecordScriptId.value = null
        state.recordingScriptId.value = null
        state.samples.value = emptyMap()
        state.error.value = currentAppText(
            "采集失败，请保持单人正对镜头后重新录制。",
            "Capture failed. Keep one person facing the camera and record again."
        )
        facePresenceTracker.cancelRecording()
        syncFacePresence()
        if (failure == FacePresenceFailure.ANALYSIS_STALLED) {
            onTerminalInterrupted(currentAppText(
                "摄像头检测中断，本次采集已结束，请重新开始。",
                "Camera detection was interrupted. This capture has ended. Please start again."
            ))
        } else {
            onCollectionInvalidated()
        }
    }

    private fun invalidateCollection(message: String) {
        state.samples.value.values.forEach { sample ->
            File(sample.filePath).takeIf(File::exists)?.delete()
        }
        state.samples.value = emptyMap()
        state.error.value = message
        facePresenceTracker.cancelRecording()
        syncFacePresence()
        onCollectionInvalidated()
    }

    private fun syncFacePresence() {
        state.facePresence.value = facePresenceTracker.snapshot
    }

    private fun scriptRef(script: VoiceCloneScriptItem): Map<String, String?> =
        mapOf("scriptRef" to voiceCloneLogRef(script.scriptId))

    private fun recordingMetrics(
        script: VoiceCloneScriptItem,
        durationMs: Long
    ): Map<String, String?> = scriptRef(script) + mapOf("durationMs" to durationMs.toString())

    private fun isRecordAudioGranted(): Boolean = androidx.core.content.ContextCompat.checkSelfPermission(
        context,
        android.Manifest.permission.RECORD_AUDIO
    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
}
