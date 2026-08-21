package com.vvtech.aiassistant.features.assistant

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.Toast
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.repository.TaskRepository
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallPhase
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallRequest
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallSpec
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallUiState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.LocalDate

internal class AssistantOtaRuntimeController(
    private val state: AssistantOtaRuntimeState,
    private val deps: AssistantOtaRuntimeDeps
) {
    var otaUpdateChecking by state.otaUpdateChecking
    var otaUpdateDialog by state.otaUpdateDialog
    var otaInstallState by state.otaInstallState
    var pendingInstallRequest by state.pendingInstallRequest

    val installer: FinalOtaUpdateInstaller = state.installer

    fun onInstallActivityResult(result: ActivityResult) {
        installer.onInstallActivityResult(result.resultCode)
    }

    fun onInstallPermissionActivityReturned() {
        logOta("OTA_INSTALL_PERMISSION_RETURNED", "returned", "permission_activity_result")
        AppFileLogger.i("FinalOtaInstaller", "install permission activity returned")
        pendingInstallRequest = installer.nextInstallRequest()
    }

    fun clearPendingInstallRequest() {
        pendingInstallRequest = null
    }

    fun launchInstallRequest(
        request: FinalOtaInstallRequest,
        installLauncher: ActivityResultLauncher<Intent>,
        permissionLauncher: ActivityResultLauncher<Intent>
    ) {
        when (request) {
            is FinalOtaInstallRequest.Install -> runCatching {
                logOta("OTA_INSTALL_LAUNCH_STARTED", "started", "package_installer")
                installLauncher.launch(request.intent)
            }.onFailure { throwable ->
                logOta(
                    "OTA_INSTALL_LAUNCH_FAILED",
                    "failed",
                    "package_installer_launch_failure",
                    throwable = throwable
                )
                installer.markLaunchFailed(throwable)
            }

            is FinalOtaInstallRequest.Permission -> runCatching {
                logOta("OTA_PERMISSION_LAUNCH_STARTED", "started", "unknown_sources_permission")
                permissionLauncher.launch(request.intent)
            }.onFailure { throwable ->
                logOta(
                    "OTA_PERMISSION_LAUNCH_FAILED",
                    "failed",
                    "permission_launch_failure",
                    throwable = throwable
                )
                installer.markLaunchFailed(throwable)
            }

            FinalOtaInstallRequest.None ->
                logOta("OTA_INSTALL_LAUNCH_SKIPPED", "skipped", "no_pending_request")
        }
    }

    fun checkVersionUpdate(showNoUpdatePrompt: Boolean, startupCheck: Boolean) {
        if (otaUpdateChecking) {
            logOta("OTA_VERSION_CHECK_SKIPPED", "skipped", "already_checking")
            return
        }
        val startedAt = System.currentTimeMillis()
        logOta(
            "OTA_VERSION_CHECK_STARTED",
            "started",
            if (startupCheck) "startup_check" else "manual_check"
        )
        val today = LocalDate.now().toString()
        val forceRequiredBeforeCheck = deps.prefs.getBoolean(FinalOtaForceUpdateRequiredKey, false)
        deps.scope.launch {
            otaUpdateChecking = true
            runCatching {
                deps.taskRepository.checkAppVersion(
                    packageName = BuildConfig.APPLICATION_ID,
                    currentVersionCode = BuildConfig.VERSION_CODE.toLong(),
                    currentVersionName = BuildConfig.VERSION_NAME,
                    deviceId = AccountIdentityProvider.accountId.takeIf { it.isNotBlank() },
                    channel = BuildConfig.FLAVOR.takeIf { it.isNotBlank() }
                )
            }.onSuccess { response ->
                logOta(
                    eventType = "OTA_VERSION_CHECK_COMPLETED",
                    result = if (response.hasUpdate) "update_available" else "up_to_date",
                    reason = if (startupCheck) "startup_check" else "manual_check",
                    elapsedMs = System.currentTimeMillis() - startedAt,
                    attributes = mapOf(
                        "versionCode" to response.versionCode.toString(),
                        "forceUpdate" to response.forceUpdate.toString()
                    )
                )
                val forceUpdateRequiredAfterCheck = otaForceUpdateRequiredFromResponse(
                    hasUpdate = response.hasUpdate,
                    forceUpdate = response.forceUpdate
                )
                deps.prefs.edit()
                    .putBoolean(FinalOtaForceUpdateRequiredKey, forceUpdateRequiredAfterCheck)
                    .putString(FinalOtaLastStartupCheckDateKey, today)
                    .apply()
                otaUpdateDialog = when {
                    response.hasUpdate -> {
                        val installSpec = FinalOtaInstallSpec(
                            versionName = response.versionName,
                            versionCode = response.versionCode,
                            apkUrl = response.apkUrl,
                            downloadHeaders = response.downloadHeaders,
                            checksumSha256 = response.checksumSha256,
                            fileSize = response.fileSize
                        )
                        val restoredDownloadedPackage = installer.prepareDownloadedPackageIfAvailable(
                            spec = installSpec,
                            reason = if (startupCheck) "startup_version_check" else "manual_version_check"
                        )
                        AppFileLogger.i(
                            "FinalOtaInstaller",
                            "version check has update startup=$startupCheck restoredDownloadedPackage=$restoredDownloadedPackage " +
                                "version=${response.versionName} versionCode=${response.versionCode} force=$forceUpdateRequiredAfterCheck"
                        )
                        if (!restoredDownloadedPackage) {
                            installer.reset()
                        }
                        FinalOtaUpdateDialogState(
                            hasUpdate = true,
                            versionName = response.versionName,
                            versionCode = response.versionCode,
                            releaseNotes = response.releaseNotes,
                            forceUpdate = forceUpdateRequiredAfterCheck,
                            apkUrl = response.apkUrl,
                            downloadHeaders = response.downloadHeaders,
                            fileSize = response.fileSize,
                            checksumSha256 = response.checksumSha256
                        )
                    }
                    else -> {
                        if (showNoUpdatePrompt) {
                            Toast.makeText(deps.context, currentAppText("当前已是最新版本", "You Are Up to Date"), Toast.LENGTH_SHORT).show()
                        }
                        null
                    }
                }
            }.onFailure { throwable ->
                logOta(
                    eventType = "OTA_VERSION_CHECK_FAILED",
                    result = "failed",
                    reason = if (startupCheck) "startup_check_failure" else "manual_check_failure",
                    elapsedMs = System.currentTimeMillis() - startedAt,
                    throwable = throwable
                )
                if (!startupCheck || forceRequiredBeforeCheck) {
                    Toast.makeText(
                        deps.context,
                        throwable.message ?: currentAppText("版本检测失败，请稍后重试", "Version check failed. Try again later"),
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
            otaUpdateChecking = false
        }
    }

    fun runStartupCheckIfNeeded() {
        val forceUpdateRequired = deps.prefs.getBoolean(FinalOtaForceUpdateRequiredKey, false)
        val today = LocalDate.now().toString()
        val lastCheckDate = deps.prefs.getString(FinalOtaLastStartupCheckDateKey, null)
        if (shouldRunStartupOtaCheck(forceUpdateRequired, lastCheckDate, today)) {
            checkVersionUpdate(showNoUpdatePrompt = false, startupCheck = true)
        }
    }

    fun handlePrimaryAction(dialogState: FinalOtaUpdateDialogState) {
        if (dialogState.apkUrl.isBlank()) {
            logOta("OTA_PRIMARY_ACTION_BLOCKED", "blocked", "missing_apk_url")
            Toast.makeText(deps.context, currentAppText("下载地址为空，请稍后重试", "Download URL is empty. Try again later"), Toast.LENGTH_SHORT).show()
            return
        }
        when (otaInstallState.phase) {
            FinalOtaInstallPhase.Downloaded,
            FinalOtaInstallPhase.WaitingForInstallPermission,
            FinalOtaInstallPhase.Installing -> {
                logOta(
                    "OTA_PRIMARY_ACTION_REQUESTED",
                    "install_requested",
                    otaInstallState.phase.name.lowercase()
                )
                pendingInstallRequest = installer.nextInstallRequest()
            }

            FinalOtaInstallPhase.Downloading,
            FinalOtaInstallPhase.Verifying ->
                logOta(
                    "OTA_PRIMARY_ACTION_SKIPPED",
                    "skipped",
                    otaInstallState.phase.name.lowercase()
                )

            FinalOtaInstallPhase.Idle,
            FinalOtaInstallPhase.Failed -> {
                logOta(
                    "OTA_DOWNLOAD_STARTED",
                    "started",
                    otaInstallState.phase.name.lowercase(),
                    attributes = mapOf("versionCode" to dialogState.versionCode.toString())
                )
                installer.startDownload(
                    scope = deps.scope,
                    spec = FinalOtaInstallSpec(
                        versionName = dialogState.versionName,
                        versionCode = dialogState.versionCode,
                        apkUrl = dialogState.apkUrl,
                        downloadHeaders = dialogState.downloadHeaders,
                        checksumSha256 = dialogState.checksumSha256,
                        fileSize = dialogState.fileSize
                    ),
                    onReadyToInstall = {
                        pendingInstallRequest = installer.nextInstallRequest()
                    }
                )
            }
        }
    }

    fun openDownload(apkUrl: String) {
        if (apkUrl.isBlank()) {
            logOta("OTA_EXTERNAL_DOWNLOAD_BLOCKED", "blocked", "missing_apk_url")
            Toast.makeText(deps.context, currentAppText("下载地址为空，请稍后重试", "Download URL is empty. Try again later"), Toast.LENGTH_SHORT).show()
            return
        }
        runCatching {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(apkUrl))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            deps.context.startActivity(intent)
            logOta("OTA_EXTERNAL_DOWNLOAD_OPENED", "opened", "external_intent")
        }.onFailure { throwable ->
            logOta(
                "OTA_EXTERNAL_DOWNLOAD_FAILED",
                "failed",
                "external_intent_failure",
                throwable = throwable
            )
            val message = if (throwable is ActivityNotFoundException) {
                "未找到可打开下载链接的应用"
            } else {
                throwable.message ?: currentAppText("无法打开下载链接", "Unable to open download link")
            }
            Toast.makeText(deps.context, message, Toast.LENGTH_SHORT).show()
        }
    }

    fun dismissDialog(dialogState: FinalOtaUpdateDialogState) {
        if (!dialogState.forceUpdate) {
            installer.cancelActiveDownload(removeFile = true)
            otaUpdateDialog = null
        }
    }

    fun applyOverlayArgs(args: AssistantOverlayHostArgs) {
        args.otaUpdateDialog = otaUpdateDialog
        args.otaInstallState = otaInstallState
        args.onDismissOtaDialog = ::dismissDialog
        args.onOtaPrimaryAction = ::handlePrimaryAction
    }

    fun onLifecycleInstallRequest(request: FinalOtaInstallRequest) {
        pendingInstallRequest = request
    }

    private fun logOta(
        eventType: String,
        result: String,
        reason: String,
        elapsedMs: Long? = null,
        attributes: Map<String, String?> = emptyMap(),
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.OTA,
            eventType = eventType,
            provider = BuildConfig.FLAVOR,
            result = result,
            reason = reason,
            elapsedMs = elapsedMs,
            attributes = attributes + ("exceptionType" to throwable?.javaClass?.simpleName)
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}

internal class AssistantOtaRuntimeState(
    val otaUpdateChecking: MutableState<Boolean>,
    val otaUpdateDialog: MutableState<FinalOtaUpdateDialogState?>,
    val otaInstallState: MutableState<FinalOtaInstallUiState>,
    val pendingInstallRequest: MutableState<FinalOtaInstallRequest?>,
    val installer: FinalOtaUpdateInstaller
)

internal data class AssistantOtaRuntimeDeps(
    val context: Context,
    val prefs: SharedPreferences,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

@Composable
internal fun rememberAssistantOtaRuntimeController(
    deps: AssistantOtaRuntimeDeps
): AssistantOtaRuntimeController {
    val installState = remember { mutableStateOf(FinalOtaInstallUiState.Idle) }
    val installer = remember(deps.context) {
        FinalOtaUpdateInstaller(deps.context) { nextState ->
            installState.value = nextState
        }
    }
    val state = AssistantOtaRuntimeState(
        otaUpdateChecking = rememberSaveable { mutableStateOf(false) },
        otaUpdateDialog = remember { mutableStateOf<FinalOtaUpdateDialogState?>(null) },
        otaInstallState = installState,
        pendingInstallRequest = remember { mutableStateOf<FinalOtaInstallRequest?>(null) },
        installer = installer
    )
    return remember(deps.context, deps.taskRepository, deps.scope) {
        AssistantOtaRuntimeController(state, deps)
    }
}

@Composable
internal fun FinalOtaRuntimeEffects(
    lifecycleOwner: LifecycleOwner,
    runtime: AssistantOtaRuntimeController,
    installLauncher: ActivityResultLauncher<Intent>,
    permissionLauncher: ActivityResultLauncher<Intent>
) {
    FinalOtaInstallerLifecycleEffect(
        otaInstaller = runtime.installer,
        lifecycleOwner = lifecycleOwner,
        onInstallRequest = runtime::onLifecycleInstallRequest
    )
    FinalOtaInstallEffect(
        FinalOtaInstallEffectArgs(
            runtime.pendingInstallRequest,
            runtime::clearPendingInstallRequest
        ) { request ->
            runtime.launchInstallRequest(request, installLauncher, permissionLauncher)
        }
    )
    LaunchedEffect(Unit) {
        runtime.runStartupCheckIfNeeded()
    }
}
