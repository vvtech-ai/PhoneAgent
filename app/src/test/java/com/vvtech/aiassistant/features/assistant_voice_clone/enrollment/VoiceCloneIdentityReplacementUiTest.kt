package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneIdentityReplacementUiTest {

    @Test
    fun `replacement confirmation is shown before permission and provider initialization`() {
        val ui = source("VoiceCloneEnrollmentUi.kt")
        val coordinator = source("VoiceCloneEnrollmentCoordinator.kt")
        val replacementGate = source("VoiceCloneIdentityReplacementGate.kt")

        assertTrue(ui.contains("将替换当前认证身份"))
        assertTrue(ui.contains("继续并替换"))
        assertTrue(ui.contains("onPrepareVerification"))
        assertTrue(ui.contains("rememberMfvcVerificationPermissionGate"))
        assertTrue(replacementGate.contains("checkReplacement"))
        assertTrue(coordinator.contains("replacementConfirmed = snapshot.replacementConfirmed"))
    }

    private fun source(name: String): String {
        val path =
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/$name"
        return listOf(File(path), File("android/app/$path"))
            .first { it.exists() }
            .readText(Charsets.UTF_8)
    }
}
