package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallRequest

internal data class FinalOtaInstallEffectArgs(
    val pendingOtaInstallRequest: FinalOtaInstallRequest?,
    val onClearPendingOtaInstallRequest: () -> Unit,
    val onLaunchOtaInstallRequest: (FinalOtaInstallRequest) -> Unit
)

@Composable
internal fun FinalOtaInstallEffect(args: FinalOtaInstallEffectArgs) {
    LaunchedEffect(args.pendingOtaInstallRequest) {
        val request = args.pendingOtaInstallRequest ?: return@LaunchedEffect
        args.onClearPendingOtaInstallRequest()
        args.onLaunchOtaInstallRequest(request)
    }
}
