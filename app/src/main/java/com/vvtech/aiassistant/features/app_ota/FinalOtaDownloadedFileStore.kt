package com.vvtech.aiassistant.features.app_ota

import android.content.Context
import com.vvtech.aiassistant.logging.AppFileLogger
import java.io.File

private const val StorePrefsName = "final_ota_installer"
private const val DownloadedFilePathKey = "downloaded_file_path"
private const val DownloadedFileSizeKey = "downloaded_file_size"
private const val DownloadedVersionNameKey = "downloaded_version_name"
private const val DownloadedVersionCodeKey = "downloaded_version_code"
private const val DownloadedChecksumSha256Key = "downloaded_checksum_sha256"
private const val LogTag = "FinalOtaInstaller"

internal data class FinalOtaDownloadedFileRecord(
    val path: String,
    val expectedSize: Long,
    val versionName: String,
    val versionCode: Long?,
    val checksumSha256: String = ""
) {
    fun matches(spec: FinalOtaInstallSpec): Boolean {
        return matchesVersion(spec) && matchesChecksum(spec)
    }

    fun matchesVersion(spec: FinalOtaInstallSpec): Boolean {
        val recordCode = versionCode ?: -1L
        val specCode = spec.versionCode ?: -1L
        val codeMatches = recordCode > 0L && specCode > 0L && recordCode == specCode
        val nameMatches = versionName.isNotBlank() &&
            spec.versionName.isNotBlank() &&
            versionName == spec.versionName
        return codeMatches || nameMatches
    }

    private fun matchesChecksum(spec: FinalOtaInstallSpec): Boolean {
        val specChecksum = spec.checksumSha256.trim()
        if (specChecksum.isBlank()) return true
        val recordChecksum = checksumSha256.trim()
        return recordChecksum.isNotBlank() && recordChecksum.equals(specChecksum, ignoreCase = true)
    }

    fun fileOrNull(): File? {
        val file = File(path)
        return file.takeIf {
            it.isFile &&
                it.length() > 0L &&
                (expectedSize <= 0L || it.length() >= expectedSize)
        }
    }

    fun summary(): String =
        "path=$path expectedSize=$expectedSize version=$versionName versionCode=${versionCode ?: -1L} " +
            "checksum=${checksumSha256.take(12).ifBlank { "missing" }}"
}

internal class FinalOtaDownloadedFileStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(StorePrefsName, Context.MODE_PRIVATE)

    fun remember(file: File, spec: FinalOtaInstallSpec) {
        val committed = prefs.edit()
            .putString(DownloadedFilePathKey, file.absolutePath)
            .putLong(DownloadedFileSizeKey, spec.fileSize ?: file.length())
            .putString(DownloadedVersionNameKey, spec.versionName)
            .putLong(DownloadedVersionCodeKey, spec.versionCode ?: -1L)
            .putString(DownloadedChecksumSha256Key, spec.checksumSha256.trim())
            .commit()
        AppFileLogger.i(
            LogTag,
            "downloaded file recorded path=${file.absolutePath} length=${file.length()} " +
                "version=${spec.versionName} versionCode=${spec.versionCode ?: -1L} " +
                "checksum=${spec.checksumSha256.trim().take(12).ifBlank { "missing" }} committed=$committed"
        )
        if (!committed) {
            AppFileLogger.w(LogTag, "downloaded file record commit failed path=${file.absolutePath}")
        }
    }

    fun readRecord(): FinalOtaDownloadedFileRecord? {
        val path = prefs.getString(DownloadedFilePathKey, null)?.takeIf { it.isNotBlank() }
            ?: return null
        val code = prefs.getLong(DownloadedVersionCodeKey, -1L).takeIf { it > 0L }
        return FinalOtaDownloadedFileRecord(
            path = path,
            expectedSize = prefs.getLong(DownloadedFileSizeKey, -1L),
            versionName = prefs.getString(DownloadedVersionNameKey, null).orEmpty(),
            versionCode = code,
            checksumSha256 = prefs.getString(DownloadedChecksumSha256Key, null).orEmpty()
        )
    }

    fun restoreMatchingFile(spec: FinalOtaInstallSpec, reason: String): File? {
        val record = readRecord()
        if (record == null) {
            AppFileLogger.i(LogTag, "downloaded file restore skipped reason=$reason record=missing")
            return null
        }
        if (!record.matches(spec)) {
            if (record.matchesVersion(spec) && spec.checksumSha256.isNotBlank()) {
                val deleted = runCatching { File(record.path).delete() }.getOrDefault(false)
                clear()
                AppFileLogger.i(
                    LogTag,
                    "downloaded file restore skipped reason=$reason record=checksum_mismatch " +
                        "specVersion=${spec.versionName} specVersionCode=${spec.versionCode ?: -1L} " +
                        "specChecksum=${spec.checksumSha256.trim().take(12)} deleted=$deleted ${record.summary()}"
                )
                return null
            }
            AppFileLogger.i(
                LogTag,
                "downloaded file restore skipped reason=$reason record=version_mismatch " +
                    "specVersion=${spec.versionName} specVersionCode=${spec.versionCode ?: -1L} ${record.summary()}"
            )
            return null
        }
        return restoreRecord(record, reason)
    }

    fun restoreAfterProcessRestart(reason: String = "process_restart"): File? {
        val record = readRecord() ?: return null
        return restoreRecord(record, reason)
    }

    private fun restoreRecord(record: FinalOtaDownloadedFileRecord, reason: String): File? {
        val file = File(record.path)
        val expectedSize = record.expectedSize
        if (!file.isFile || file.length() <= 0L || (expectedSize > 0L && file.length() < expectedSize)) {
            AppFileLogger.w(
                LogTag,
                "recorded downloaded file unavailable reason=$reason path=${record.path} " +
                    "length=${file.length()} expectedSize=$expectedSize"
            )
            clear()
            return null
        }
        AppFileLogger.i(
            LogTag,
            "downloaded file restored reason=$reason path=${record.path} length=${file.length()} " +
                "version=${record.versionName} versionCode=${record.versionCode ?: -1L}"
        )
        return file
    }

    fun clear() {
        val committed = prefs.edit()
            .remove(DownloadedFilePathKey)
            .remove(DownloadedFileSizeKey)
            .remove(DownloadedVersionNameKey)
            .remove(DownloadedVersionCodeKey)
            .remove(DownloadedChecksumSha256Key)
            .commit()
        AppFileLogger.i(LogTag, "downloaded file record cleared committed=$committed")
    }
}
