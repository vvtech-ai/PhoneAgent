package com.vvtech.aiassistant.features.assistant_shell

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.assistant.AssistantOtaRuntimeController
import com.vvtech.aiassistant.features.assistant.FinalOtaRuntimeEffects

@Composable
internal fun AssistantOtaRuntimeShellEffects(
    lifecycleOwner: LifecycleOwner,
    runtime: AssistantOtaRuntimeController
) {
    val otaInstallLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(),
        onResult = runtime::onInstallActivityResult
    )
    val otaInstallPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) {
        runtime.onInstallPermissionActivityReturned()
    }
    FinalOtaRuntimeEffects(
        lifecycleOwner = lifecycleOwner,
        runtime = runtime,
        installLauncher = otaInstallLauncher,
        permissionLauncher = otaInstallPermissionLauncher
    )
}
