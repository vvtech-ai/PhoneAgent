package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalAuthCodeRetryEffect

internal data class AssistantAuthCodeRetryShellEffectArgs(
    val mockLoggedIn: Boolean,
    val authCodeRetrySeconds: Int,
    val onRetrySecondsChange: (Int) -> Unit
)

@Composable
internal fun AssistantAuthCodeRetryShellEffect(args: AssistantAuthCodeRetryShellEffectArgs) {
    FinalAuthCodeRetryEffect(
        mockLoggedIn = args.mockLoggedIn,
        authCodeRetrySeconds = args.authCodeRetrySeconds,
        onRetrySecondsChange = args.onRetrySecondsChange
    )
}
