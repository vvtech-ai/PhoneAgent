package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceCloneRecordingControllerGuardTest {
    @Test
    fun runtimeDelegatesRecordingSideEffectsToRecordingController() {
        val runtime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantVoiceCloneRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val recording = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/AssistantVoiceCloneRecordingController.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(runtime.lines().size < 500)
        assertTrue(recording.lines().size <= 300)
        assertTrue(runtime.contains("private val recordingController: AssistantVoiceCloneRecordingController"))

        listOf(
            "fun clearDraft(deleteFiles: Boolean = true) = recordingController.clearDraft(deleteFiles)",
            "fun requestRecord(script: VoiceCloneScriptItem, requestAudioPermission: () -> Unit) =",
            "recordingController.requestRecord(script, requestAudioPermission)",
            "fun onRecordAudioPermissionResult(granted: Boolean) =",
            "fun beginRecording(script: VoiceCloneScriptItem) = recordingController.beginRecording(script)",
            "fun finishRecording(script: VoiceCloneScriptItem) = recordingController.finishRecording(script)",
            "fun togglePreview(script: VoiceCloneScriptItem) = recordingController.togglePreview(script)",
            "fun disposeResources() {",
            "enrollmentCoordinator.reset()",
            "recordingController.disposeResources()",
            "fun terminateAndReset(message: String? = null)",
            "recordingController.terminateCapture()"
        ).forEach { token ->
            assertTrue("runtime should keep thin delegate: $token", runtime.contains(token))
        }

        listOf(
            "recorder.start(script.scriptId)",
            "recorder.stop()",
            "previewPlayer.toggle(sample.filePath)",
            "VoiceCloneAudioQualityAnalyzer.analyze(",
            "private fun isRecordAudioGranted()",
            "androidx.core.content.ContextCompat.checkSelfPermission"
        ).forEach { token ->
            assertFalse("recording side effect should stay out of runtime: $token", runtime.contains(token))
            assertTrue("recording controller should own side effect: $token", recording.contains(token))
        }
    }

    @Test
    fun enrollmentProgressIsNotSaveableAndLifecycleCleanupIsFeatureLocal() {
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantVoiceCloneRuntimeFactory.kt"
        ).readText(Charsets.UTF_8)
        val lifecycle = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/VoiceCloneLifecycleEffect.kt"
        ).readText(Charsets.UTF_8)

        listOf(
            "recordingScriptId = remember {",
            "pendingRecordScriptId = remember {",
            "enrollment = remember {",
            "submissionState = remember {"
        ).forEach { token -> assertTrue("progress must not survive reconstruction: $token", factory.contains(token)) }
        assertTrue(lifecycle.contains("ProcessLifecycleOwner.get().lifecycle"))
        assertTrue(lifecycle.contains("Lifecycle.Event.ON_STOP"))
        assertFalse(lifecycle.contains("Lifecycle.Event.ON_PAUSE"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
