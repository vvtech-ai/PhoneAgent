package com.vvtech.aiassistant.features.assistant_translation

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.features.assistant.localizeTranslationCallStatusText
import java.util.Locale

internal data class TranslationCallPolledStatusPlan(
    val audioChannelStatus: String? = null,
    val error: String? = null,
    val shouldExit: Boolean = false
)

internal object TranslationCallPolledStatusPolicy {
    fun apply(
        currentStatus: TranslationCallStatusResponse,
        previousError: String?
    ): TranslationCallPolledStatusPlan {
        val callState = currentStatus.callState.uppercase(Locale.ROOT)
        val audioChannelStatus = currentStatus.statusMessage
            .takeIf { it.isNotBlank() }
            ?.let(::localizeTranslationCallStatusText)
        val error = if (callState == "FAILED") {
            localizeTranslationCallStatusText(currentStatus.statusMessage.ifBlank { previousError.orEmpty() })
        } else {
            null
        }
        return TranslationCallPolledStatusPlan(
            audioChannelStatus = audioChannelStatus,
            error = error,
            shouldExit = callState == "ENDED" || callState == "FAILED"
        )
    }
}
