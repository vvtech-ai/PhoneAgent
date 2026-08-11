package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSummary
import com.vvtech.aiassistant.model.VoiceCloneFacePresenceUploadRequest
import com.vvtech.aiassistant.model.VoiceCloneSampleUploadRequest
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneUploadRequest
import java.io.File
import java.util.Base64

internal object VoiceCloneUploadRequestFactory {
    fun create(
        attemptId: String,
        collectionId: String,
        scriptVersion: String,
        script: VoiceCloneScriptItem,
        sample: VoiceCloneLocalSample,
        facePresence: FacePresenceSummary
    ): VoiceCloneUploadRequest = VoiceCloneUploadRequest(
        verificationAttemptId = attemptId,
        collectionId = collectionId,
        displayName = "我的声音",
        scriptVersion = scriptVersion,
        facePresence = VoiceCloneFacePresenceUploadRequest(
            sampledFrames = facePresence.sampledFrames,
            singleFaceFrames = facePresence.singleFaceFrames,
            maxMissingDurationMs = facePresence.maxMissingDurationMs,
            multipleFaceDetected = facePresence.multipleFaceDetected,
            maxFrameGapMs = facePresence.maxFrameGapMs
        ),
        samples = listOf(
            VoiceCloneSampleUploadRequest(
                scriptId = script.scriptId,
                text = script.text,
                audioBase64 = Base64.getEncoder().encodeToString(File(sample.filePath).readBytes()),
                audioFormat = "wav",
                durationMs = sample.durationMs
            )
        )
    )
}
