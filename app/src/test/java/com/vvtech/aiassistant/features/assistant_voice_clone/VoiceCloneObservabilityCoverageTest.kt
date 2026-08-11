package com.vvtech.aiassistant.features.assistant_voice_clone

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneObservabilityCoverageTest {
    @Test
    fun enrollmentRecordingAndUploadExposeStableStageEvents() {
        val enrollment = source(
            "features/assistant_voice_clone/enrollment/VoiceCloneEnrollmentLogger.kt"
        )
        val recording = source(
            "features/assistant_voice_clone/AssistantVoiceCloneRecordingController.kt"
        )
        val upload = source(
            "features/assistant/AssistantVoiceCloneRuntimeController.kt"
        )

        listOf(
            "VOICE_CLONE_VERIFICATION_STARTED",
            "VOICE_CLONE_SDK_FINISHED",
            "VOICE_CLONE_CLIENT_OBSERVATION_FINISHED",
            "VOICE_CLONE_VERIFICATION_STATUS_CHANGED",
            "VOICE_CLONE_MFVC_COMPLETION_ACCEPTED",
            "VOICE_CLONE_ACTIVATION_FINISHED"
        ).forEach { event -> assertTrue("missing enrollment event $event", enrollment.contains(event)) }
        listOf(
            "VOICE_CLONE_MIC_PERMISSION_RESULT",
            "VOICE_CLONE_CAMERA_FAILED",
            "VOICE_CLONE_FACE_GATE_FAILED",
            "VOICE_CLONE_RECORDING_REJECTED",
            "VOICE_CLONE_RECORDING_COMPLETED"
        ).forEach { event -> assertTrue("missing recording event $event", recording.contains(event)) }
        listOf(
            "VOICE_CLONE_UPLOAD_STARTED",
            "VOICE_CLONE_UPLOAD_COMPLETED",
            "VOICE_CLONE_UPLOAD_FAILED"
        ).forEach { event -> assertTrue("missing upload event $event", upload.contains(event)) }
    }

    @Test
    fun enrollmentLoggerDoesNotReferenceIdentityOrMediaPayloadFields() {
        val logger = source(
            "features/assistant_voice_clone/enrollment/VoiceCloneEnrollmentLogger.kt"
        )
        listOf("realName", "idCardNumber", "certifyId", "scriptText", "filePath", "audioBase64")
            .forEach { sensitive -> assertFalse("logger references $sensitive", logger.contains(sensitive)) }
        assertFalse("logger must not receive raw SDK result", logger.contains("IdProSdkResult"))
    }

    @Test
    fun sdkRawReasonStopsAtTheClassifierBoundary() {
        val coordinator = source(
            "features/assistant_voice_clone/enrollment/VoiceCloneEnrollmentCoordinator.kt"
        )
        val classifier = source(
            "features/assistant_voice_clone/enrollment/AliyunIdProSdkResultClassifier.kt"
        )

        assertTrue(coordinator.contains("AliyunIdProSdkResultClassifier.classify(result)"))
        assertFalse(coordinator.contains("result.reason"))
        assertTrue(classifier.contains("result.reason.uppercase()"))
    }

    private fun source(relativePath: String): String {
        val file = listOf(
            File("src/main/java/com/vvtech/aiassistant/$relativePath"),
            File("android/app/src/main/java/com/vvtech/aiassistant/$relativePath")
        ).first { it.exists() }
        return file.readText(Charsets.UTF_8)
    }
}
