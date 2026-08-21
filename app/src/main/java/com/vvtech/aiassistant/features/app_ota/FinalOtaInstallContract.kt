package com.vvtech.aiassistant.features.app_ota

import android.content.Intent
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal enum class FinalOtaInstallPhase {
    Idle,
    Downloading,
    Verifying,
    Downloaded,
    WaitingForInstallPermission,
    Installing,
    Failed
}

internal data class FinalOtaInstallUiState(
    val phase: FinalOtaInstallPhase = FinalOtaInstallPhase.Idle,
    val progressPercent: Int? = null,
    val message: String = "",
    val error: String = ""
) {
    val primaryButtonEnabled: Boolean
        get() = phase != FinalOtaInstallPhase.Downloading &&
            phase != FinalOtaInstallPhase.Verifying &&
            phase != FinalOtaInstallPhase.Installing

    val primaryButtonLabel: String
        get() = when (phase) {
            FinalOtaInstallPhase.Downloading -> progressPercent?.let {
                currentAppText("下载中 $it%", "Downloading $it%")
            } ?: currentAppText("下载中", "Downloading")
            FinalOtaInstallPhase.Verifying -> currentAppText("校验中", "Verifying")
            FinalOtaInstallPhase.Downloaded -> currentAppText("安装", "Install")
            FinalOtaInstallPhase.WaitingForInstallPermission -> currentAppText("授权安装", "Allow Install")
            FinalOtaInstallPhase.Installing -> currentAppText("等待安装", "Waiting to Install")
            FinalOtaInstallPhase.Failed -> currentAppText("重新下载", "Download Again")
            FinalOtaInstallPhase.Idle -> currentAppText("立即更新", "Update Now")
        }

    companion object {
        val Idle = FinalOtaInstallUiState()
    }
}

internal data class FinalOtaInstallSpec(
    val versionName: String,
    val versionCode: Long?,
    val apkUrl: String,
    val downloadHeaders: Map<String, String> = emptyMap(),
    val checksumSha256: String,
    val fileSize: Long?
)

internal sealed class FinalOtaInstallRequest {
    data class Install(val intent: Intent) : FinalOtaInstallRequest()
    data class Permission(val intent: Intent) : FinalOtaInstallRequest()
    object None : FinalOtaInstallRequest()
}
