package com.vvtech.aiassistant.features.assistant_agent

import android.os.SystemClock
import java.util.concurrent.atomic.AtomicReference

internal data class AgentInitialLaunch(
    val skillId: String?,
    val opening: String?
)

internal object AgentInitialSkillLaunchStore {
    private const val ValidityMillis = 5 * 60 * 1000L

    private data class Pending(
        val skillId: String?,
        val opening: String?,
        val backendOpening: String?,
        val sendBackendOpening: Boolean,
        val createdAt: Long,
        val sessionId: String? = null,
        val openingPresented: Boolean = false
    )

    private val pending = AtomicReference<Pending?>(null)

    fun arm(
        skillId: String,
        opening: String? = null,
        now: Long = SystemClock.elapsedRealtime()
    ) {
        armWithBackendOpening(
            skillId = skillId,
            opening = opening,
            backendOpening = opening,
            sendBackendOpening = true,
            now = now
        )
    }

    fun armWithBackendOpening(
        skillId: String,
        opening: String? = null,
        backendOpening: String? = opening,
        sendBackendOpening: Boolean = true,
        now: Long = SystemClock.elapsedRealtime()
    ) {
        val normalized = skillId.trim()
        require(normalized.isNotEmpty())
        val normalizedOpening = opening?.trim()?.takeIf(String::isNotEmpty)
        val normalizedBackendOpening = backendOpening?.trim()?.takeIf(String::isNotEmpty)
        pending.set(
            Pending(
                skillId = normalized,
                opening = normalizedOpening,
                backendOpening = normalizedBackendOpening,
                sendBackendOpening = sendBackendOpening,
                createdAt = now
            )
        )
    }

    fun rememberOpening(
        opening: String,
        now: Long = SystemClock.elapsedRealtime()
    ) {
        val normalizedOpening = opening.trim()
        require(normalizedOpening.isNotEmpty())
        while (true) {
            val value = pending.get()
            val next = if (value == null || now - value.createdAt > ValidityMillis) {
                Pending(
                    skillId = null,
                    opening = normalizedOpening,
                    backendOpening = null,
                    sendBackendOpening = false,
                    createdAt = now,
                    openingPresented = true
                )
            } else {
                value.copy(opening = normalizedOpening, openingPresented = true)
            }
            if (pending.compareAndSet(value, next)) return
        }
    }

    fun peekOpening(now: Long = SystemClock.elapsedRealtime()): String? {
        while (true) {
            val value = pending.get() ?: return null
            if (now - value.createdAt <= ValidityMillis) return value.opening
            if (pending.compareAndSet(value, null)) return null
        }
    }

    fun peekPresentedOpeningForSession(
        sessionId: String,
        now: Long = SystemClock.elapsedRealtime(),
    ): String? {
        val normalizedSessionId = sessionId.trim()
        if (normalizedSessionId.isEmpty()) return null
        while (true) {
            val value = pending.get() ?: return null
            if (now - value.createdAt > ValidityMillis || value.sessionId != normalizedSessionId) {
                if (now - value.createdAt > ValidityMillis && pending.compareAndSet(value, null)) {
                    return null
                }
                if (value.sessionId != normalizedSessionId) return null
                continue
            }
            return value.opening.takeIf { value.openingPresented }
        }
    }

    fun bindToSession(sessionId: String, now: Long = SystemClock.elapsedRealtime()): Boolean {
        val normalizedSessionId = sessionId.trim()
        if (normalizedSessionId.isEmpty()) return false
        while (true) {
            val value = pending.get() ?: return false
            if (now - value.createdAt > ValidityMillis ||
                value.sessionId?.let { it != normalizedSessionId } == true
            ) {
                if (pending.compareAndSet(value, null)) return false
                continue
            }
            if (value.sessionId == normalizedSessionId) return true
            if (pending.compareAndSet(value, value.copy(sessionId = normalizedSessionId))) return true
        }
    }

    fun takeLaunch(
        sessionId: String,
        now: Long = SystemClock.elapsedRealtime()
    ): AgentInitialLaunch? {
        val normalizedSessionId = sessionId.trim()
        while (true) {
            val value = pending.get() ?: return null
            if (now - value.createdAt > ValidityMillis || value.sessionId != normalizedSessionId) {
                if (pending.compareAndSet(value, null)) return null
                continue
            }
            if (pending.compareAndSet(value, null)) {
                return AgentInitialLaunch(
                    skillId = value.skillId,
                    opening = if (value.sendBackendOpening) {
                        value.backendOpening ?: value.opening.takeIf { value.openingPresented }
                    } else {
                        null
                    }
                )
            }
        }
    }

    fun take(sessionId: String, now: Long = SystemClock.elapsedRealtime()): String? =
        takeLaunch(sessionId, now)?.skillId

    fun clear() {
        pending.set(null)
    }
}
