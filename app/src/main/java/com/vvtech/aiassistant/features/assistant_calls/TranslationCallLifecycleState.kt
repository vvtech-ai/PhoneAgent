package com.vvtech.aiassistant.features.assistant_calls

import java.util.UUID

internal data class TranslationCallFinalization(
    val recordCallId: String,
    val origin: TranslationCallOrigin
)

internal data class TranslationCallLifecycleSnapshot(
    val activeAttemptId: String = "",
    val origin: TranslationCallOrigin = TranslationCallOrigin.EXISTING_FLOW,
    val finalizedSinceBegin: Boolean = false
)

internal class TranslationCallLifecycleState(
    initial: TranslationCallLifecycleSnapshot = TranslationCallLifecycleSnapshot(),
    private val onSnapshotChange: (TranslationCallLifecycleSnapshot) -> Unit = {}
) {
    private var snapshot = initial

    fun begin(origin: TranslationCallOrigin): String {
        update(
            TranslationCallLifecycleSnapshot(
                activeAttemptId = UUID.randomUUID().toString(),
                origin = origin
            )
        )
        return snapshot.activeAttemptId
    }

    fun currentAttemptId(): String = snapshot.activeAttemptId

    fun isActive(attemptId: String): Boolean {
        return snapshot.activeAttemptId == attemptId && !snapshot.finalizedSinceBegin
    }

    fun tryFinalize(
        attemptId: String,
        remoteCallId: String
    ): TranslationCallFinalization? {
        if (attemptId.isBlank() || attemptId != snapshot.activeAttemptId) {
            return null
        }
        if (snapshot.finalizedSinceBegin) return null
        val identity = snapshot.activeAttemptId.ifBlank { attemptId.ifBlank { remoteCallId } }
        update(snapshot.copy(finalizedSinceBegin = true))
        return TranslationCallFinalization(
            recordCallId = remoteCallId.ifBlank { "local:$identity" },
            origin = snapshot.origin
        )
    }

    fun clear() {
        update(
            snapshot.copy(
                activeAttemptId = "",
                origin = TranslationCallOrigin.EXISTING_FLOW,
                finalizedSinceBegin = true
            )
        )
    }

    private fun update(next: TranslationCallLifecycleSnapshot) {
        snapshot = next
        onSnapshotChange(next)
    }
}
