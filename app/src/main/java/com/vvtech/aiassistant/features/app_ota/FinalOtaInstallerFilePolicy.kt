package com.vvtech.aiassistant.features.app_ota

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import java.io.File
import java.util.Locale

private const val OtaApkMimeType = "application/vnd.android.package-archive"

internal fun finalOtaTargetFile(context: Context, spec: FinalOtaInstallSpec): File {
    val version = spec.versionName.ifBlank { spec.versionCode?.toString().orEmpty() }.ifBlank { "latest" }
    val checksumPart = finalOtaChecksumFilePart(spec.checksumSha256)
    val fileName = buildString {
        append("chaken-ai-")
        append(version)
        if (checksumPart != null) {
            append("-")
            append(checksumPart)
        }
        append(".apk")
    }
        .replace(Regex("[^A-Za-z0-9._-]+"), "_")
        .lowercase(Locale.US)
    return File(finalOtaDownloadRoot(context), fileName)
}

internal fun finalOtaFileProviderAuthority(context: Context): String =
    "${context.packageName}.ota.fileprovider"

internal fun finalOtaInstallIntent(uri: Uri): Intent {
    return Intent(Intent.ACTION_INSTALL_PACKAGE)
        .setDataAndType(uri, OtaApkMimeType)
        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        .putExtra(Intent.EXTRA_RETURN_RESULT, true)
        .putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
}

internal fun finalOtaInstallPermissionIntent(context: Context): Intent {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}")
        )
    } else {
        Intent(Settings.ACTION_SECURITY_SETTINGS)
    }
}

internal fun finalOtaSafeUrlForLog(rawUrl: String): String {
    val uri = runCatching { Uri.parse(rawUrl) }.getOrNull() ?: return "<invalid>"
    return buildString {
        append(uri.scheme ?: "")
        append("://")
        append(uri.host ?: "")
        if (uri.port != -1) {
            append(":")
            append(uri.port)
        }
        append(uri.encodedPath ?: "")
        if (!uri.encodedQuery.isNullOrBlank()) {
            append("?<redacted>")
        }
    }
}

private fun finalOtaDownloadRoot(context: Context): File {
    val root = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        ?: context.filesDir
    return File(root, "ota").apply { mkdirs() }
}

private fun finalOtaChecksumFilePart(checksumSha256: String): String? {
    val normalized = checksumSha256.trim().lowercase(Locale.US)
    if (normalized.length < 8 || normalized.any { it !in '0'..'9' && it !in 'a'..'f' }) {
        return null
    }
    return normalized.take(12)
}
