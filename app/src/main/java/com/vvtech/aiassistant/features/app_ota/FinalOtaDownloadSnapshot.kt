package com.vvtech.aiassistant.features.app_ota

import android.app.DownloadManager
import android.database.Cursor
import java.io.File

internal data class FinalOtaDownloadSnapshot(
    val status: Int,
    val reason: Int?,
    val downloadedBytes: Long,
    val totalBytes: Long,
    val downloadManagerDownloadedBytes: Long,
    val fileDownloadedBytes: Long,
    val downloadManagerTotalBytes: Long,
    val apiTotalBytes: Long,
    val downloadedSource: String,
    val totalSource: String,
    val progressPercent: Int?
)

internal fun Cursor.finalOtaDownloadSnapshot(
    file: File,
    fallbackTotalBytes: Long?
): FinalOtaDownloadSnapshot? {
    if (!moveToFirst()) {
        return null
    }
    val downloadManagerDownloaded =
        longColumn(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR) ?: 0L
    val fileDownloaded = file.length().coerceAtLeast(0L)
    val downloaded = when {
        downloadManagerDownloaded > 0L -> downloadManagerDownloaded
        fileDownloaded > 0L -> fileDownloaded
        else -> 0L
    }
    val downloadManagerTotal = longColumn(DownloadManager.COLUMN_TOTAL_SIZE_BYTES) ?: -1L
    val apiTotal = fallbackTotalBytes?.takeIf { it > 0L } ?: -1L
    val total = when {
        downloadManagerTotal > 0L -> downloadManagerTotal
        apiTotal > 0L -> apiTotal
        else -> -1L
    }
    return FinalOtaDownloadSnapshot(
        status = intColumn(DownloadManager.COLUMN_STATUS) ?: DownloadManager.STATUS_FAILED,
        reason = intColumn(DownloadManager.COLUMN_REASON),
        downloadedBytes = downloaded,
        totalBytes = total,
        downloadManagerDownloadedBytes = downloadManagerDownloaded,
        fileDownloadedBytes = fileDownloaded,
        downloadManagerTotalBytes = downloadManagerTotal,
        apiTotalBytes = apiTotal,
        downloadedSource = when {
            downloadManagerDownloaded > 0L -> "download_manager"
            fileDownloaded > 0L -> "file_length"
            else -> "none"
        },
        totalSource = when {
            downloadManagerTotal > 0L -> "download_manager"
            apiTotal > 0L -> "api_file_size"
            else -> "none"
        },
        progressPercent = if (total > 0L) {
            ((downloaded.coerceAtMost(total) * 100L) / total).toInt().coerceIn(0, 100)
        } else {
            null
        }
    )
}

private fun Cursor.intColumn(name: String): Int? {
    val index = getColumnIndex(name)
    return if (index >= 0) getInt(index) else null
}

private fun Cursor.longColumn(name: String): Long? {
    val index = getColumnIndex(name)
    return if (index >= 0) getLong(index) else null
}
