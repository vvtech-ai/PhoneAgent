package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.util.concurrent.atomic.AtomicBoolean

internal class MfvcVerificationSessionState {
    private val active = AtomicBoolean(false)

    fun tryStart(): Boolean = active.compareAndSet(false, true)

    fun finish() {
        active.set(false)
    }

    fun isActive(): Boolean = active.get()

    fun shouldSuppressLauncherRelaunch(
        action: String?,
        categories: Set<String>?,
        hasSavedState: Boolean
    ): Boolean = isActive() &&
        !hasSavedState &&
        action == ACTION_MAIN &&
        categories?.contains(CATEGORY_LAUNCHER) == true

    private companion object {
        const val ACTION_MAIN = "android.intent.action.MAIN"
        const val CATEGORY_LAUNCHER = "android.intent.category.LAUNCHER"
    }
}

internal object MfvcVerificationSession {
    private val state = MfvcVerificationSessionState()

    fun tryStart(): Boolean = state.tryStart()

    fun finish() = state.finish()

    fun shouldSuppressLauncherRelaunch(
        action: String?,
        categories: Set<String>?,
        hasSavedState: Boolean
    ): Boolean = state.shouldSuppressLauncherRelaunch(action, categories, hasSavedState)
}
