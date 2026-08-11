package com.vvtech.aiassistant.features.app_ota

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FinalOtaUpdateInstallerBoundaryGuardTest {
    @Test
    fun installerDelegatesInstallContractAndDownloadSnapshotParsing() {
        val installerFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalOtaUpdateInstaller.kt"
        )
        val contractFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/app_ota/FinalOtaInstallContract.kt"
        )
        val snapshotFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/app_ota/FinalOtaDownloadSnapshot.kt"
        )
        val installer = installerFile.readText(Charsets.UTF_8)
        val contract = contractFile.readText(Charsets.UTF_8)
        val snapshot = snapshotFile.readText(Charsets.UTF_8)

        assertTrue(installerFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(contractFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(snapshotFile.readLines(Charsets.UTF_8).size <= 300)

        assertTrue(installer.contains("features.app_ota.FinalOtaInstallUiState"))
        assertTrue(installer.contains("features.app_ota.FinalOtaDownloadSnapshot"))
        assertTrue(installer.contains("cursor.finalOtaDownloadSnapshot(file, fallbackTotalBytes)"))

        listOf(
            "internal enum class FinalOtaInstallPhase",
            "internal data class FinalOtaInstallUiState",
            "internal data class FinalOtaInstallSpec",
            "internal sealed class FinalOtaInstallRequest",
            "private data class DownloadSnapshot",
            "private fun Cursor.intColumn(",
            "private fun Cursor.longColumn(",
            "COLUMN_BYTES_DOWNLOADED_SO_FAR",
            "COLUMN_TOTAL_SIZE_BYTES"
        ).forEach { token ->
            assertFalse("installer should not own OTA contract/snapshot token: $token", installer.contains(token))
        }

        listOf(
            "internal enum class FinalOtaInstallPhase",
            "internal data class FinalOtaInstallUiState",
            "internal data class FinalOtaInstallSpec",
            "internal sealed class FinalOtaInstallRequest"
        ).forEach { token ->
            assertTrue("contract should own token: $token", contract.contains(token))
        }

        listOf(
            "internal data class FinalOtaDownloadSnapshot",
            "internal fun Cursor.finalOtaDownloadSnapshot(",
            "DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR",
            "DownloadManager.COLUMN_TOTAL_SIZE_BYTES",
            "file.length().coerceAtLeast(0L)",
            "progressPercent = if (total > 0L)"
        ).forEach { token ->
            assertTrue("snapshot boundary should own token: $token", snapshot.contains(token))
        }
    }

    @Test
    fun downloadedFileRecordMatchesSameVersionAndRejectsMismatchedVersion() {
        val record = FinalOtaDownloadedFileRecord(
            path = "sample.apk",
            expectedSize = 1024L,
            versionName = "1.0.24",
            versionCode = 18L,
            checksumSha256 = "a".repeat(64)
        )

        assertTrue(
            record.matches(
                FinalOtaInstallSpec(
                    versionName = "1.0.24",
                    versionCode = 18L,
                    apkUrl = "https://example.com/app.apk",
                    checksumSha256 = "a".repeat(64),
                    fileSize = 1024L
                )
            )
        )
        assertFalse(
            record.matches(
                FinalOtaInstallSpec(
                    versionName = "1.0.25",
                    versionCode = 19L,
                    apkUrl = "https://example.com/app.apk",
                    checksumSha256 = "a".repeat(64),
                    fileSize = 1024L
                )
            )
        )
        assertEquals(
            "path=sample.apk expectedSize=1024 version=1.0.24 versionCode=18 checksum=aaaaaaaaaaaa",
            record.summary()
        )
    }

    @Test
    fun downloadedFileRecordRejectsSameVersionWhenChecksumChanges() {
        val record = FinalOtaDownloadedFileRecord(
            path = "sample.apk",
            expectedSize = 1024L,
            versionName = "1.0.24",
            versionCode = 18L
        )

        assertFalse(
            "same version with new checksum must force a fresh download",
            record.matches(
                FinalOtaInstallSpec(
                    versionName = "1.0.24",
                    versionCode = 18L,
                    apkUrl = "https://example.com/app-new.apk",
                    checksumSha256 = "b".repeat(64),
                    fileSize = 1024L
                )
            )
        )
    }

    @Test
    fun installerKeepsDownloadedPackageAcrossVersionCheckAndPermissionReturn() {
        val installer = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalOtaUpdateInstaller.kt"
        ).readText(Charsets.UTF_8)
        val runtime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantOtaRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val lifecycle = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantLifecycleEffects.kt"
        ).readText(Charsets.UTF_8)
        val store = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/app_ota/FinalOtaDownloadedFileStore.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(store.contains(".commit()"))
        assertTrue(store.contains("DownloadedChecksumSha256Key"))
        assertTrue(store.contains("record=checksum_mismatch"))
        assertTrue(store.contains("fun restoreMatchingFile(spec: FinalOtaInstallSpec, reason: String)"))
        assertTrue(installer.contains("prepareDownloadedPackageIfAvailable(spec: FinalOtaInstallSpec, reason: String)"))
        assertTrue(installer.contains("resumeInstallAfterPermissionIfReady(reason: String)"))
        assertTrue(runtime.contains("restoredDownloadedPackage"))
        assertTrue(runtime.contains("if (!restoredDownloadedPackage)"))
        assertTrue(runtime.contains("installer.reset()"))
        assertTrue(lifecycle.contains("resumeInstallAfterPermissionIfReady(\"app_resume\")"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
