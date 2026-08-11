package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MfvcVerificationSessionStateTest {

    @Test
    fun `only one sdk session can be active and next session starts after finish`() {
        val state = MfvcVerificationSessionState()

        assertTrue(state.tryStart())
        assertFalse(state.tryStart())

        state.finish()

        assertTrue(state.tryStart())
    }

    @Test
    fun `launcher relaunch is suppressed only while mfvc sdk is active`() {
        val state = MfvcVerificationSessionState()

        assertFalse(
            state.shouldSuppressLauncherRelaunch(
                action = ACTION_MAIN,
                categories = setOf(CATEGORY_LAUNCHER),
                hasSavedState = false
            )
        )

        assertTrue(state.tryStart())
        assertTrue(
            state.shouldSuppressLauncherRelaunch(
                action = ACTION_MAIN,
                categories = setOf(CATEGORY_LAUNCHER),
                hasSavedState = false
            )
        )
        assertFalse(
            state.shouldSuppressLauncherRelaunch(
                action = ACTION_MAIN,
                categories = setOf(CATEGORY_LAUNCHER),
                hasSavedState = true
            )
        )
        assertFalse(
            state.shouldSuppressLauncherRelaunch(
                action = "android.intent.action.VIEW",
                categories = setOf(CATEGORY_LAUNCHER),
                hasSavedState = false
            )
        )
    }

    @Test
    fun `main activity rejects sdk launcher reentry before compose starts`() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/MainActivity.kt"
        ).readText(Charsets.UTF_8)
        val guardIndex = source.indexOf("MfvcVerificationSession.shouldSuppressLauncherRelaunch")
        val composeIndex = source.indexOf("setContent {")

        assertTrue(guardIndex >= 0)
        assertTrue(composeIndex > guardIndex)
        assertTrue(source.contains("VOICE_CLONE_SDK_LAUNCHER_REENTRY_SUPPRESSED"))
        assertTrue(source.substring(guardIndex, composeIndex).contains("finish()"))
    }

    private companion object {
        const val ACTION_MAIN = "android.intent.action.MAIN"
        const val CATEGORY_LAUNCHER = "android.intent.category.LAUNCHER"

        fun sourceFile(path: String): File =
            listOf(File(path), File("android/app/$path")).first { it.exists() }
    }
}
