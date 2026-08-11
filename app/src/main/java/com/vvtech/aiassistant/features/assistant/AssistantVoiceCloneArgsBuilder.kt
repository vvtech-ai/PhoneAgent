package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentUiArgs
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState

internal class AssistantVoiceCloneArgsBuilderInput(
    val status: VoiceCloneStatusInput,
    val recording: VoiceCloneRecordingInput,
    val guide: VoiceCloneGuideInput,
    val callbacks: VoiceCloneCallbacksInput
)

internal class VoiceCloneStatusInput(
    val voiceCloneStatus: VoiceCloneStatusResponse?,
    val voiceCloneLoading: Boolean,
    val voiceCloneError: String?
)

internal class VoiceCloneRecordingInput(
    val voiceCloneScripts: List<VoiceCloneScriptItem>,
    val voiceCloneSamples: Map<String, VoiceCloneLocalSample>,
    val voiceCloneUploading: Boolean,
    val voiceCloneActionLoading: Boolean,
    val voiceCloneRecordingScriptId: String?,
    val voiceCloneFace: VoiceCloneFaceUiArgs
)

internal class VoiceCloneGuideInput(
    val voiceCloneEnrollment: VoiceCloneEnrollmentUiArgs,
    val voiceCloneSubmissionState: VoiceCloneSubmissionState,
    val voiceCloneCurrentScriptIndex: Int
)

internal class VoiceCloneCallbacksInput(
    val onRefreshVoiceCloneStatus: () -> Unit,
    val onSelectAiVoiceForCalls: () -> Unit,
    val onSelectCloneVoiceForCalls: () -> Unit,
    val onOpenVoiceCloneFlow: (Boolean) -> Unit,
    val onVoiceCloneRecord: (VoiceCloneScriptItem) -> Unit,
    val onVoiceCloneStop: (VoiceCloneScriptItem) -> Unit,
    val onSubmitVoiceCloneRecording: () -> Unit,
    val onVoiceCloneRerecord: () -> Unit,
    val onStartUsingVoiceClone: (Boolean) -> Unit,
    val onVoiceCloneLifecycleInterrupted: () -> Unit
)

internal fun buildAssistantVoiceCloneArgs(
    input: AssistantVoiceCloneArgsBuilderInput
): VoiceCloneArgs = VoiceCloneArgs().also { args ->
    with(input.status) {
        args.voiceCloneStatus = voiceCloneStatus
        args.voiceCloneLoading = voiceCloneLoading
        args.voiceCloneError = voiceCloneError
    }
    args.onRefreshVoiceCloneStatus = input.callbacks.onRefreshVoiceCloneStatus
    with(input.recording) {
        args.voiceCloneScripts = voiceCloneScripts
        args.voiceCloneSamples = voiceCloneSamples
        args.voiceCloneUploading = voiceCloneUploading
        args.voiceCloneActionLoading = voiceCloneActionLoading
        args.voiceCloneRecordingScriptId = voiceCloneRecordingScriptId
        args.voiceCloneFace = voiceCloneFace
    }
    with(input.guide) {
        args.voiceCloneEnrollment = voiceCloneEnrollment
        args.voiceCloneSubmissionState = voiceCloneSubmissionState
        args.voiceCloneCurrentScriptIndex = voiceCloneCurrentScriptIndex
    }
    with(input.callbacks) {
        args.onSelectAiVoiceForCalls = onSelectAiVoiceForCalls
        args.onSelectCloneVoiceForCalls = onSelectCloneVoiceForCalls
        args.onOpenVoiceCloneFlow = onOpenVoiceCloneFlow
        args.onVoiceCloneRecord = onVoiceCloneRecord
        args.onVoiceCloneStop = onVoiceCloneStop
        args.onSubmitVoiceCloneRecording = onSubmitVoiceCloneRecording
        args.onVoiceCloneRerecord = onVoiceCloneRerecord
        args.onStartUsingVoiceClone = onStartUsingVoiceClone
        args.onVoiceCloneLifecycleInterrupted = onVoiceCloneLifecycleInterrupted
    }
}
