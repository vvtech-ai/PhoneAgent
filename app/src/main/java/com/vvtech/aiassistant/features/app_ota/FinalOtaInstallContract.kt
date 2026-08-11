package com.vvtech.aiassistant.features.app_ota

import android.content.Intent

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
            FinalOtaInstallPhase.Downloading -> progressPercent?.let { "下载中 $it%" } ?: "下载中"
            FinalOtaInstallPhase.Verifying -> "校验中"
            FinalOtaInstallPhase.Downloaded -> "安装"
            FinalOtaInstallPhase.WaitingForInstallPermission -> "授权安装"
            FinalOtaInstallPhase.Installing -> "等待安装"
            FinalOtaInstallPhase.Failed -> "重新下载"
            FinalOtaInstallPhase.Idle -> "立即更新"
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
