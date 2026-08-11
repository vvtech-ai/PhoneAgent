package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalAccountIdentityEffect
import com.vvtech.aiassistant.features.assistant.FinalAccountIdentityEffectArgs

internal data class AssistantAccountIdentityShellEffectArgs(
    val activeAccountId: String,
    val mockLoggedIn: Boolean,
    val onLoadCallRecordsForAccount: (String) -> Unit,
    val onClearCallRecordsForCurrentAccount: () -> Unit,
    val onAccountIdentityChanged: (Boolean) -> Unit
)

@Composable
internal fun AssistantAccountIdentityShellEffect(args: AssistantAccountIdentityShellEffectArgs) {
    FinalAccountIdentityEffect(
        FinalAccountIdentityEffectArgs(
            activeAccountId = args.activeAccountId,
            mockLoggedIn = args.mockLoggedIn,
            onLoadCallRecordsForAccount = args.onLoadCallRecordsForAccount,
            onClearCallRecordsForCurrentAccount = args.onClearCallRecordsForCurrentAccount,
            onAccountIdentityChanged = args.onAccountIdentityChanged
        )
    )
}
