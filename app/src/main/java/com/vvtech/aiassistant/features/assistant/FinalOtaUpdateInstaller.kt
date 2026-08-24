package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.app.Activity
import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.vvtech.aiassistant.features.app_ota.FinalOtaDownloadSnapshot
import com.vvtech.aiassistant.features.app_ota.FinalOtaDownloadedFileStore
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallPhase
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallRequest
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallSpec
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallUiState
import com.vvtech.aiassistant.features.app_ota.finalOtaFileProviderAuthority
import com.vvtech.aiassistant.features.app_ota.finalOtaDownloadSnapshot
import com.vvtech.aiassistant.features.app_ota.finalOtaInstallIntent
import com.vvtech.aiassistant.features.app_ota.finalOtaInstallPermissionIntent
import com.vvtech.aiassistant.features.app_ota.finalOtaSafeUrlForLog
import com.vvtech.aiassistant.features.app_ota.finalOtaTargetFile
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val OtaApkMimeType = "application/vnd.android.package-archive"
private const val OtaDownloadPollMs = 500L
private const val OtaDownloadSnapshotLogMs = 2_000L
private const val OtaLogTag = "FinalOtaInstaller"

internal class FinalOtaUpdateInstaller(
    context: Context,
    private val onStateChange: (FinalOtaInstallUiState) -> Unit
) {
    private val appContext = context.applicationContext
    private val downloadManager =
        appContext.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val downloadedFileStore = FinalOtaDownloadedFileStore(appContext)

    private var downloadJob: Job? = null
    private var activeDownloadId: Long? = null
    private var activeFile: File? = null
    private var state: FinalOtaInstallUiState = FinalOtaInstallUiState.Idle
    private var installResultReceived = false
    private var lastLoggedSnapshot: FinalOtaDownloadSnapshot? = null
    private var nextSnapshotLogAtMs: Long = 0L

    fun reset() {
        AppFileLogger.i(OtaLogTag, "installer reset clears active download and downloaded file record")
        downloadJob?.cancel()
        activeDownloadId = null
        activeFile = null
        installResultReceived = false
        lastLoggedSnapshot = null
        nextSnapshotLogAtMs = 0L
        downloadedFileStore.clear()
        updateState(FinalOtaInstallUiState.Idle)
    }

    fun prepareDownloadedPackageIfAvailable(spec: FinalOtaInstallSpec, reason: String): Boolean {
        val file = activeFile?.takeIf { it.isFile && it.length() > 0L }
            ?: downloadedFileStore.restoreMatchingFile(spec, reason)?.also { activeFile = it }
        if (file == null) {
            AppFileLogger.i(
                OtaLogTag,
                "prepare downloaded package skipped reason=$reason result=no_matching_file " +
                    "version=${spec.versionName} versionCode=${spec.versionCode ?: -1L}"
            )
            return false
        }
        downloadJob?.cancel()
        activeDownloadId = null
        installResultReceived = false
        lastLoggedSnapshot = null
        nextSnapshotLogAtMs = 0L
        val canInstall = canRequestPackageInstalls()
        AppFileLogger.i(
            OtaLogTag,
            "prepare downloaded package success reason=$reason file=${file.absolutePath} " +
                "length=${file.length()} canInstall=$canInstall"
        )
        val nextPhase = if (canInstall) FinalOtaInstallPhase.Downloaded else FinalOtaInstallPhase.WaitingForInstallPermission
        val nextMessage = if (canInstall) {
            "\u4e0b\u8f7d\u5b8c\u6210\uff0c\u51c6\u5907\u5b89\u88c5"
        } else {
            "\u9700\u8981\u5141\u8bb8\u672c\u5e94\u7528\u5b89\u88c5\u672a\u77e5\u6765\u6e90\u5e94\u7528"
        }
        updateState(
            FinalOtaInstallUiState(
                phase = nextPhase,
                progressPercent = 100,
                message = nextMessage
            )
        )
        return true
    }

    fun dispose() {
        downloadJob?.cancel()
    }

    fun cancelActiveDownload(removeFile: Boolean) {
        downloadJob?.cancel()
        activeDownloadId?.let { id ->
            runCatching { downloadManager.remove(id) }
        }
        if (removeFile) {
            activeFile?.delete()
        }
        activeDownloadId = null
        activeFile = null
        installResultReceived = false
        lastLoggedSnapshot = null
        nextSnapshotLogAtMs = 0L
        downloadedFileStore.clear()
        AppFileLogger.i(OtaLogTag, "download canceled removeFile=$removeFile")
        updateState(FinalOtaInstallUiState.Idle)
    }

    fun startDownload(
        scope: CoroutineScope,
        spec: FinalOtaInstallSpec,
        onReadyToInstall: () -> Unit
    ) {
        if (state.phase == FinalOtaInstallPhase.Downloading || state.phase == FinalOtaInstallPhase.Verifying) {
            return
        }
        downloadJob?.cancel()
        activeDownloadId?.let { id -> runCatching { downloadManager.remove(id) } }
        lastLoggedSnapshot = null
        nextSnapshotLogAtMs = 0L
        downloadedFileStore.clear()
        val file = finalOtaTargetFile(appContext, spec).also { target ->
            target.parentFile?.mkdirs()
            if (target.exists()) {
                target.delete()
            }
        }
        activeFile = file
        AppFileLogger.i(
                OtaLogTag,
                "download start version=${spec.versionName} versionCode=${spec.versionCode} " +
                "fileSize=${spec.fileSize ?: -1L} url=${finalOtaSafeUrlForLog(spec.apkUrl)} " +
                "headerNames=${spec.downloadHeaders.keys.joinToString(",")} target=${file.absolutePath}"
        )
        val request = runCatching {
            DownloadManager.Request(Uri.parse(spec.apkUrl))
                .setTitle("Phone Agent ${spec.versionName.ifBlank { currentAppText("更新包", "Update package") }}")
                .setDescription(currentAppText("正在下载应用更新", "Downloading app update"))
                .setMimeType(OtaApkMimeType)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setDestinationUri(Uri.fromFile(file))
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
        }.getOrElse { throwable ->
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Failed,
                    message = currentAppText("下载未开始", "Download not started"),
                    error = throwable.message ?: currentAppText("下载地址无效", "Invalid download URL")
                )
            )
            AppFileLogger.w(OtaLogTag, "download request create failed url=${finalOtaSafeUrlForLog(spec.apkUrl)}", throwable)
            return
        }
        applyDownloadHeaders(request, spec.downloadHeaders)
        val downloadId = runCatching { downloadManager.enqueue(request) }
            .getOrElse { throwable ->
                updateState(
                    FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Failed,
                    message = currentAppText("下载未开始", "Download not started"),
                    error = throwable.message ?: currentAppText(
                        "系统下载服务不可用",
                        "System download service is unavailable"
                    )
                    )
                )
                AppFileLogger.w(OtaLogTag, "download enqueue failed url=${finalOtaSafeUrlForLog(spec.apkUrl)}", throwable)
                return
            }
        activeDownloadId = downloadId
        AppFileLogger.i(OtaLogTag, "download enqueued id=$downloadId target=${file.absolutePath}")
        updateState(
            FinalOtaInstallUiState(
                phase = FinalOtaInstallPhase.Downloading,
                progressPercent = null,
                message = currentAppText("正在下载安装包", "Downloading update package")
            )
        )
        downloadJob = scope.launch {
            pollDownload(downloadId, file, spec, onReadyToInstall)
        }
    }

    private fun applyDownloadHeaders(request: DownloadManager.Request, headers: Map<String, String>) {
        headers.forEach { (name, value) ->
            val headerName = name.trim()
            val headerValue = value.trim()
            if (headerName.isNotEmpty() && headerValue.isNotEmpty()) {
                request.addRequestHeader(headerName, headerValue)
                AppFileLogger.d(OtaLogTag, "download header added name=$headerName")
            }
        }
    }

    fun nextInstallRequest(): FinalOtaInstallRequest {
        val file = activeFile?.takeIf { it.isFile && it.length() > 0L }
            ?: downloadedFileStore.restoreAfterProcessRestart("install_request")?.also { activeFile = it }
        if (file == null || !file.isFile || file.length() <= 0L) {
            AppFileLogger.w(
                OtaLogTag,
                "install request unavailable file=${file?.absolutePath} length=${file?.length()} " +
                    "record=${downloadedFileStore.readRecord()?.summary() ?: "missing"}"
            )
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Failed,
                    message = currentAppText("安装包不可用", "Update package unavailable"),
                    error = currentAppText("请重新下载更新包", "Please download the update package again")
                )
            )
            return FinalOtaInstallRequest.None
        }
        if (!canRequestPackageInstalls()) {
            AppFileLogger.i(
                OtaLogTag,
                "install request needs unknown-source permission file=${file.absolutePath} length=${file.length()}"
            )
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.WaitingForInstallPermission,
                    message = currentAppText(
                        "需要允许本应用安装未知来源应用",
                        "Allow this app to install unknown apps"
                    )
                )
            )
            return FinalOtaInstallRequest.Permission(finalOtaInstallPermissionIntent(appContext))
        }
        val uri = runCatching {
            FileProvider.getUriForFile(appContext, finalOtaFileProviderAuthority(appContext), file)
        }.getOrElse { throwable ->
            AppFileLogger.w(OtaLogTag, "install uri create failed file=${file.absolutePath}", throwable)
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Failed,
                    message = currentAppText("无法准备安装包", "Unable to prepare update package"),
                    error = throwable.message ?: currentAppText("FileProvider 配置异常", "FileProvider configuration error")
                )
            )
            return FinalOtaInstallRequest.None
        }
        installResultReceived = false
        AppFileLogger.i(OtaLogTag, "install intent ready file=${file.absolutePath} length=${file.length()} uri=$uri")
        updateState(
            FinalOtaInstallUiState(
                phase = FinalOtaInstallPhase.Installing,
                message = currentAppText("正在打开系统安装器", "Opening system installer")
            )
        )
        return FinalOtaInstallRequest.Install(finalOtaInstallIntent(uri))
    }

    fun markLaunchFailed(throwable: Throwable) {
        AppFileLogger.w(OtaLogTag, "install launcher failed", throwable)
        updateState(
            FinalOtaInstallUiState(
                phase = FinalOtaInstallPhase.Downloaded,
                message = currentAppText("安装器打开失败", "Failed to open installer"),
                error = throwable.message ?: currentAppText(
                    "未找到可安装 APK 的系统组件",
                    "No system component can install the APK"
                )
            )
        )
    }

    fun onInstallActivityResult(resultCode: Int) {
        installResultReceived = true
        AppFileLogger.i(OtaLogTag, "install activity result resultCode=$resultCode")
        if (resultCode == Activity.RESULT_OK) {
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Installing,
                    message = currentAppText("安装完成，正在切换到新版本", "Installed. Switching to the new version")
                )
            )
        } else if (state.phase == FinalOtaInstallPhase.Installing) {
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Downloaded,
                    message = currentAppText("安装未完成", "Installation not completed"),
                    error = currentAppText("可再次点击安装继续更新", "Tap Install again to continue the update")
                )
            )
        }
    }

    fun onAppResumed() {
        if (state.phase == FinalOtaInstallPhase.Installing && !installResultReceived) {
            AppFileLogger.i(OtaLogTag, "app resumed while installing without result")
            updateState(
                FinalOtaInstallUiState(
                    phase = FinalOtaInstallPhase.Downloaded,
                    message = currentAppText("安装未完成", "Installation not completed"),
                    error = currentAppText("可再次点击安装继续更新", "Tap Install again to continue the update")
                )
            )
        }
    }

    fun resumeInstallAfterPermissionIfReady(reason: String): FinalOtaInstallRequest {
        AppFileLogger.i(
            OtaLogTag,
            "resume install check reason=$reason phase=${state.phase} canInstall=${canRequestPackageInstalls()} " +
                "activeFile=${activeFile?.absolutePath ?: "none"} " +
                "record=${downloadedFileStore.readRecord()?.summary() ?: "missing"}"
        )
        if (state.phase != FinalOtaInstallPhase.WaitingForInstallPermission || !canRequestPackageInstalls()) {
            if (state.phase == FinalOtaInstallPhase.WaitingForInstallPermission) {
                AppFileLogger.i(OtaLogTag, "resume install check permission still missing reason=$reason")
            }
            return FinalOtaInstallRequest.None
        }
        AppFileLogger.i(OtaLogTag, "resume install check permission granted reason=$reason")
        return nextInstallRequest()
    }

    private suspend fun pollDownload(
        downloadId: Long,
        file: File,
        spec: FinalOtaInstallSpec,
        onReadyToInstall: () -> Unit
    ) {
        while (downloadJob?.isActive == true) {
            val snapshot = downloadSnapshot(downloadId, file, spec.fileSize)
            if (snapshot == null) {
                AppFileLogger.w(OtaLogTag, "download snapshot missing id=$downloadId")
                updateState(
                    FinalOtaInstallUiState(
                        phase = FinalOtaInstallPhase.Failed,
                        message = currentAppText("下载失败", "Download failed"),
                        error = currentAppText("系统下载任务不存在", "System download task does not exist")
                    )
                )
                return
            }
            when (snapshot.status) {
                DownloadManager.STATUS_PENDING,
                DownloadManager.STATUS_RUNNING,
                DownloadManager.STATUS_PAUSED -> {
                    logDownloadSnapshot(downloadId, snapshot)
                    updateState(
                        FinalOtaInstallUiState(
                            phase = FinalOtaInstallPhase.Downloading,
                            progressPercent = snapshot.progressPercent,
                            message = if (snapshot.status == DownloadManager.STATUS_PAUSED) {
                                currentAppText("下载已暂停，等待网络恢复", "Download paused. Waiting for network recovery.")
                            } else {
                                currentAppText("正在下载安装包", "Downloading update package")
                            }
                        )
                    )
                }

                DownloadManager.STATUS_SUCCESSFUL -> {
                    activeDownloadId = null
                    logDownloadSnapshot(downloadId, snapshot)
                    AppFileLogger.i(OtaLogTag, "download success id=$downloadId file=${file.absolutePath} length=${file.length()}")
                    if (!file.isFile || file.length() <= 0L) {
                        AppFileLogger.w(OtaLogTag, "download success but file empty id=$downloadId file=${file.absolutePath}")
                        updateState(
                            FinalOtaInstallUiState(
                                phase = FinalOtaInstallPhase.Failed,
                                message = currentAppText("下载失败", "Download failed"),
                                error = currentAppText("安装包文件为空", "Update package file is empty")
                            )
                        )
                        return
                    }
                    if (spec.checksumSha256.isNotBlank()) {
                        updateState(
                            FinalOtaInstallUiState(
                                phase = FinalOtaInstallPhase.Verifying,
                                progressPercent = 100,
                                message = currentAppText("正在校验安装包", "Verifying update package")
                            )
                        )
                        val matched = withContext(Dispatchers.IO) {
                            sha256(file).equals(spec.checksumSha256.trim(), ignoreCase = true)
                        }
                        if (!matched) {
                            AppFileLogger.w(OtaLogTag, "download checksum mismatch id=$downloadId file=${file.absolutePath}")
                            file.delete()
                            updateState(
                                FinalOtaInstallUiState(
                                    phase = FinalOtaInstallPhase.Failed,
                                    message = currentAppText("安装包校验失败", "Update package verification failed"),
                                    error = currentAppText("请重新下载更新包", "Please download the update package again")
                                )
                            )
                            return
                        }
                    }
                    downloadedFileStore.remember(file, spec)
                    updateState(
                        FinalOtaInstallUiState(
                            phase = FinalOtaInstallPhase.Downloaded,
                            progressPercent = 100,
                            message = currentAppText("下载完成，准备安装", "Download complete. Ready to install.")
                        )
                    )
                    onReadyToInstall()
                    return
                }

                DownloadManager.STATUS_FAILED -> {
                    activeDownloadId = null
                    logDownloadSnapshot(downloadId, snapshot, force = true)
                    updateState(
                        FinalOtaInstallUiState(
                            phase = FinalOtaInstallPhase.Failed,
                            message = currentAppText("下载失败", "Download failed"),
                            error = currentAppText(
                                "系统错误码：${snapshot.reason ?: "-"}",
                                "System error code: ${snapshot.reason ?: "-"}"
                            )
                        )
                    )
                    return
                }
            }
            delay(OtaDownloadPollMs)
        }
    }

    private fun downloadSnapshot(downloadId: Long, file: File, fallbackTotalBytes: Long?): FinalOtaDownloadSnapshot? {
        val query = DownloadManager.Query().setFilterById(downloadId)
        return downloadManager.query(query)?.use { cursor ->
            cursor.finalOtaDownloadSnapshot(file, fallbackTotalBytes)
        }
    }

    private fun logDownloadSnapshot(downloadId: Long, snapshot: FinalOtaDownloadSnapshot, force: Boolean = false) {
        val nowMs = System.currentTimeMillis()
        val changed = snapshot != lastLoggedSnapshot
        if (!force && !changed && nowMs < nextSnapshotLogAtMs) {
            return
        }
        lastLoggedSnapshot = snapshot
        nextSnapshotLogAtMs = nowMs + OtaDownloadSnapshotLogMs
        AppFileLogger.i(
            OtaLogTag,
            "download snapshot id=$downloadId status=${snapshot.status} reason=${snapshot.reason ?: -1} " +
                "downloaded=${snapshot.downloadedBytes} total=${snapshot.totalBytes} " +
                "progress=${snapshot.progressPercent ?: -1} changed=$changed " +
                "downloadedSource=${snapshot.downloadedSource} totalSource=${snapshot.totalSource} " +
                "dmDownloaded=${snapshot.downloadManagerDownloadedBytes} fileDownloaded=${snapshot.fileDownloadedBytes} " +
                "dmTotal=${snapshot.downloadManagerTotalBytes} apiTotal=${snapshot.apiTotalBytes}"
        )
    }

    private fun canRequestPackageInstalls(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            appContext.packageManager.canRequestPackageInstalls()
    }

    private fun updateState(next: FinalOtaInstallUiState) {
        if (state != next) {
            AppFileLogger.d(
                OtaLogTag,
                "state ${state.phase}->${next.phase} progress=${next.progressPercent ?: -1} " +
                    "message=${next.message} error=${next.error}"
            )
        }
        state = next
        onStateChange(next)
    }

    private suspend fun sha256(file: File): String = withContext(Dispatchers.IO) {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }

}
